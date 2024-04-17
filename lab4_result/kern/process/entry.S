.text
.globl kernel_thread_entry
kernel_thread_entry:        # void kernel_thread(void)

    pushl %edx              # push arg
    call *%ebx              # call fn 调用init_main函数

    pushl %eax              # save the return value of fn(arg) 
    call do_exit            # call do_exit to terminate current thread

# kernel_thread_entry函数主要为内核线程的主体fn函数做了一个准备开始和结束运行的“壳”，
# 并把函数fn的参数arg（保存在edx寄存器中）压栈，然后调用fn函数，
# 把函数返回值eax寄存器内容压栈，调用do_exit函数退出线程执行。