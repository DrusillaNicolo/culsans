#include <stdint.h>

extern void exit(int);
extern void ip_invalidation_test(int cid);

void thread_entry(int cid, int nc) {
    ip_invalidation_test(cid);

    while(cid)
        { asm volatile ("wfi"); }
}

int main() {
    return 0;
}