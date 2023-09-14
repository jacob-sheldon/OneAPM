//
//  OAMBacktrace.m
//  OneAPM
//
//  Created by 施治昂 on 9/12/23.
//

#import "OAMBacktrace.h"
#import <mach/mach.h>
#import <pthread/pthread.h>
#import <arm/_mcontext.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/nlist.h>

// 保存当前的函数地址和返回地址
typedef struct OAMStackFrameEntry {
    const struct OAMStackFrameEntry *const previous;
    const uintptr_t return_address;
} BSStackFrameEntry;

static mach_port_t oam_main_thread_id;

// https://juejin.cn/post/6844903944842395656
@implementation OAMBacktrace

+ (void)load {
    oam_main_thread_id = mach_thread_self();
}

+ (NSString *)oam_backtraceAllThreads {
    mach_msg_type_number_t cnt;
    thread_act_array_t list;
    kern_return_t rt = task_threads(mach_task_self(), &list, &cnt);
    if (rt != KERN_SUCCESS) {
        return @"获取所有线程调用栈失败";
    }
    
    NSMutableString *ret = [NSMutableString string];
    for (int i = 0; i < cnt; i++) {
        [ret appendString:_oam_backtraceThread(list[i])];
    }
    return ret;
}

+ (NSString *)oam_backtraceOneThread:(NSThread *)nsThread {
    thread_t thread = [self _oam_convertNSThreadToMachThread:nsThread];
    
    return _oam_backtraceThread(thread);
}

NSString *_oam_backtraceThread(thread_t thread) {
    uintptr_t backtraceBuffer[50];
    int i = 0;
    
    _STRUCT_MCONTEXT machineContext; // 线程执行状态，寄存器的值
    thread_state_t state_t = (thread_state_t)&machineContext.__ss;
    mach_msg_type_number_t state_count = ARM_THREAD_STATE64_COUNT;
    kern_return_t kr = thread_get_state(thread , ARM_THREAD_STATE64, state_t, &state_count);
    if (kr != KERN_SUCCESS) {
        printf("获取线程信息失败: %u\n", thread);
        return @"获取线程信息失败";
    }
    
    // 当前函数的地址
    uintptr_t instructionAddress = machineContext.__ss.__pc;
    backtraceBuffer[i] = instructionAddress; // 记录当前函数地址
    ++i;
    
    uintptr_t returnAddress = machineContext.__ss.__lr; // 返回地址
    if (returnAddress) {
        backtraceBuffer[i] = returnAddress; // 记录倒数第二个函数地址
        i++;
    }
    
    if (instructionAddress == 0) {
        return @"获取当前函数指令地址失败";
    }
    
    uintptr_t framePtr = machineContext.__ss.__fp; // 当前栈帧起始地址
    if (framePtr == 0) {
        return @"获取栈帧地址失败";
    }
    
    // 获取当前函数栈帧信息
    BSStackFrameEntry frame = {0};
    vm_size_t bytesCopied = 0;
    if (vm_read_overwrite(mach_task_self(), (vm_address_t)framePtr, (vm_size_t)sizeof(frame), (vm_address_t)&frame, &bytesCopied) != KERN_SUCCESS) {
        return @"获取栈帧信息失败";
    }
    
    for (; i < 50; i++) {
        backtraceBuffer[i] = frame.return_address;
        vm_size_t bytesCopied = 0;
        if (backtraceBuffer[i] == 0 || frame.previous == 0 || ((vm_read_overwrite(mach_task_self(), (vm_address_t)framePtr, sizeof(frame), (vm_address_t)&frame, &bytesCopied) != KERN_SUCCESS) != KERN_SUCCESS)) {
            break;
        }
    }
    
    NSLog(@"%ld", backtraceBuffer);
    int backtraceLen = i;
    Dl_info symbolicated[backtraceLen];
    oam_symbolicate(backtraceBuffer, symbolicated, backtraceLen, 0);
    NSMutableString *resultString = [[NSMutableString alloc] initWithFormat:@"Backtrace of Thread %u:\n", thread];
    for (int i = 0; i < backtraceLen; i++) {
        [resultString appendFormat:@"%@", oam_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
    }
    [resultString appendFormat:@"\n"];
    return [resultString copy];
}

NSString* oam_logBacktraceEntry(const int entryNum,
                                const uintptr_t address,
                                const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    
    const char* fname = oam_lastPathEntry(dlInfo->dli_fname);
    if (fname == NULL) {
        // 格式化输出指针，"0x%016lx"是输出格式
        // 将基地址进行格式化，并存储在faddrBuff中
        sprintf(faddrBuff, "0x%016lx", (uintptr_t)dlInfo->dli_fbase);
        fname = faddrBuff;
    }
    
    uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    if (sname == NULL) {
        sprintf(saddrBuff, "0x%lx", (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }
    return [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];
}

// 获取最后一个“/”符号后面的字符串
const char* oam_lastPathEntry(const char* const path) {
    if (path == NULL) {
        return NULL;
    }
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

void oam_symbolicate(const uintptr_t *const backtraceBuffer,
                     Dl_info* const symbolsBuffer,
                     const int numEntries,
                     const int skippedEntries) {
    int i = 0;
    if (!skippedEntries && i < numEntries) {
        oam_dladdr(backtraceBuffer[i], &symbolsBuffer[i]);
        i++;
    }
    for (; i < numEntries; i++) {
        oam_dladdr(((backtraceBuffer[i] & ~(3UL)) - 1), &symbolsBuffer[i]);
    }
}

// 获取指定地址的动态链接信息
bool oam_dladdr(const uintptr_t address, Dl_info* const info) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;
    
    const uint32_t idx = oam_imageIndexContainingAddress(address);
    if (idx == UINT_MAX) return false;
    const struct mach_header* header = _dyld_get_image_header(idx); // // 获取指定位置的动态库头文件
    const uintptr_t imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
    const uintptr_t addressWithSlide = address - imageVMAddrSlide; // 实际的虚拟内存地址
    const uintptr_t segBase = oam_segmentBaseOfImageIndex(idx) + imageVMAddrSlide;
    if (segBase == 0) return false;
    info->dli_fname = _dyld_get_image_name(idx);
    info->dli_fbase = (void*)header;
    
    const struct nlist_64* bestMatch = NULL; // nlist是符号表中每个符号的结构体，包含符号的名称、地址、类型等信息
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = oam_firstCmdAfterHeader(header);
    if (cmdPtr == 0) return false;
    
    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        /*
         LC_SYMTAB 加载命令包含了与link-edit符号表相关的信息，这个符号表存储了与程序或库中的全局和局部符号（如函数和变量）相关的信息，包括符号名称、符号地址、符号大小等。
         */
        if (loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command* symtabCmd = (struct symtab_command*)cmdPtr;
            const struct nlist_64* symbolTable = (struct nlist_64*)(segBase + symtabCmd->symoff); // 获取符号表的虚拟内存地址
            const uintptr_t stringTable = segBase + symtabCmd->stroff; // 获取字符串表的虚拟内存地址
            // 遍历符号表中的所有符号，找出距离address最近的一个符号
            for (uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
                if (symbolTable[iSym].n_value != 0) { // n_value不为0表示引用了外部对象
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase; // 计算符号偏移量
                    if ((addressWithSlide >= symbolBase) &&
                        (currentDistance <= bestDistance)) {
                        bestMatch = symbolTable + iSym;
                        bestDistance = currentDistance;
                    }
                }
            }
            if (bestMatch != NULL) {
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide); // 带有偏移量的运行时实际地址
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx); // 带有偏移量的名称地址
                if (*info->dli_sname == '_') { // 去掉下划线
                    info->dli_sname++;
                }
                // info->dli_saddr == info->dli_fbase 表示符号被剥离：从符号表中找不到符号信息
                // n_type == 3 表示外部全局符号
                if (info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    
    return true;
}

// 查找SEG_LINKEDIT段并返回它在文件中的偏移量
uintptr_t oam_segmentBaseOfImageIndex(const uint32_t idx) {
    const struct mach_header* header = _dyld_get_image_header(idx);
    uintptr_t cmdPtr = oam_firstCmdAfterHeader(header);
    if (cmdPtr == 0) return 0;
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
            if (strcmp(segCmd->segname, SEG_LINKEDIT) == 0) {
                return segCmd->vmaddr - segCmd->fileoff; // SEG_LINKEDIT 在文件中的偏移量
            }
        } else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64* segmentCmd = (struct segment_command_64*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}

// 找到包含指定地址的动态库
uint32_t oam_imageIndexContainingAddress(const uintptr_t address) {
    const uint32_t imageCnt = _dyld_image_count();
    const struct mach_header* header = 0;
    for (uint32_t iImg = 0; iImg < imageCnt; iImg++) {
        header = _dyld_get_image_header(iImg);
        if (header == NULL) {
            continue;
        }
        // _dyld_get_image_vmaddr_slide 获取共享库的虚拟内存地址偏移量（slide）
        // addressWSlide 得到一个校正后的地址
        uintptr_t addressWSlide = address - (uintptr_t)_dyld_get_image_vmaddr_slide(iImg);
        uintptr_t cmdPtr = oam_firstCmdAfterHeader(header);
        if (cmdPtr == 0) continue;
        
        // 遍历所有的load commands
        for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
            const struct load_command* loadCmd = (struct load_command*)cmdPtr;
            if (loadCmd->cmd == LC_SEGMENT) {
                const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
                // 32位地址时，判断address是否在这个共享库内
                if (addressWSlide >= segCmd->vmaddr &&
                    addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                    return iImg;
                }
            } else if (loadCmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64* segCmd = (struct segment_command_64*)cmdPtr;
                if (addressWSlide >= segCmd->vmaddr &&
                    addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                    return iImg;
                }
            }
            cmdPtr += loadCmd->cmdsize; // 获取下一个load command的地址
        }
    }
    
    return UINT_MAX;
}

/// 根据给定的Mach-O文件头返回加载命令（load commands）的起始地址。
uintptr_t oam_firstCmdAfterHeader(const struct mach_header* const header) {
    // header->magic 标识了文件的类型和子节序（endianness，大/小端）
    switch (header->magic) {
        // 处理32位的情况
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header+1);
        // 处理64位的情况
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0; // Header无法识别，被损坏了
    }
}

// 把NSThread转成thread_t
+ (thread_t)_oam_convertNSThreadToMachThread:(NSThread *)nsthread {
    // 获取当前应用的所有线程
    char name[256];
    mach_msg_type_number_t threadCnt;
    thread_act_array_t threadList;
    task_threads(mach_task_self(), &threadList, &threadCnt);
    
    // 给当前的nsThread起个名字，这样底层的pthread也会有同样的名字
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    NSString *threadOriginName = [nsthread name];
    [nsthread setName:[NSString stringWithFormat:@"%f", current]];
    
    if ([nsthread isMainThread]) {
        return oam_main_thread_id;
    }
    
    // 遍历所有线程，根据线程名判断哪个pthread跟nsThread是同一个线程
    for (int i = 0; i < threadCnt; i++) {
        pthread_t pt = pthread_from_mach_thread_np(threadList[i]);
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [nsthread name].UTF8String)) {
                [nsthread setName:threadOriginName];
                return threadList[i];
            }
        }
    }
    
    
    [nsthread setName:threadOriginName];
    return mach_thread_self();
}

@end
