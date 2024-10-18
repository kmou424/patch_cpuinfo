#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/sched.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>

static int __init patch_cpuinfo_init(void) {
    struct cpuinfo_x86 *cpuinfo;
    
    cpuinfo = &cpu_data(0);

    strncpy(cpuinfo->x86_model_id, "Intel(R) Core(TM) i9-13900T ES", sizeof(cpuinfo->x86_model_id));

    printk(KERN_INFO "patch_cpuinfo: model name has been changed to %s\n", cpuinfo->x86_model_id);
    return 0;
}

static void __exit patch_cpuinfo_exit(void) {
    printk(KERN_INFO "patch_cpuinfo: exited.\n");
}

module_init(patch_cpuinfo_init);
module_exit(patch_cpuinfo_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("patch cpuinfo_x86");
MODULE_AUTHOR("kmou424");
