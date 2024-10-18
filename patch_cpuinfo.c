#include <linux/module.h>

static struct kobject *patch_cpuinfo_kobj;

static void patch_model_name(const char *model_name) {
    struct cpuinfo_x86 *cpuinfo = &cpu_data(0);

    strncpy(cpuinfo->x86_model_id, model_name, sizeof(cpuinfo->x86_model_id));
    cpuinfo->x86_model_id[sizeof(cpuinfo->x86_model_id) - 1] = '\0';

    printk(KERN_INFO "patch_cpuinfo: model name has been changed to %s\n", cpuinfo->x86_model_id);
}

static ssize_t write_model_name(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count) {
    char model_name[64];
    size_t len = min(count, sizeof(model_name));

    strncpy(model_name, buf, len);

    // put end sign to last pos
    model_name[len] = '\0';

    // breakline in string, put end sign
    int breakline_pos = strcspn(model_name, "\n");
    if (breakline_pos < sizeof(model_name))
        model_name[breakline_pos] = '\0';

    patch_model_name(model_name);

    return count;
}

static struct kobj_attribute model_name_attr = __ATTR(model_name, 0200, NULL, write_model_name);

static int __init patch_cpuinfo_init(void) {
    int err;

    patch_cpuinfo_kobj = kobject_create_and_add("patch_cpuinfo", kernel_kobj);
    if (!patch_cpuinfo_kobj)
        return -ENOMEM;

    err = sysfs_create_file(patch_cpuinfo_kobj, &model_name_attr.attr);
    if (err) {
        kobject_put(patch_cpuinfo_kobj);
        return err;
    }

    patch_model_name("Intel(R) Core(TM) i9-13900T ES");

    return 0;
}

static void __exit patch_cpuinfo_exit(void) {
    kobject_put(patch_cpuinfo_kobj);
    printk(KERN_INFO "patch_cpuinfo: exited.\n");
}

module_init(patch_cpuinfo_init);
module_exit(patch_cpuinfo_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("patch cpuinfo_x86");
MODULE_AUTHOR("kmou424");
