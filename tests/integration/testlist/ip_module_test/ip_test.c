#include "../../sw/include/nb_cores.h"
#include "../../sw/include/addr_table_regs.h"
#include <stdint.h>

#define ADDR_TABLE_BASE 0x50000000UL
extern void exit(int);

#define uint128_t __uint128_t
#define NUM_CACHELINES 3 

// Entrambe le variabili nella sezione condivisa/uncached!
uint128_t data[NUM_CACHELINES] __attribute__((section(".cache_share_region")));
volatile uint32_t sync_flag __attribute__((section(".cache_share_region"))) = 0; 

void ip_invalidation_test(int cid) {
    
    // ==========================================
    // CORE 0: Il Capo (Scrive e comanda l'IP)
    // ==========================================
    if (cid == 0) {
        
        // 1. Inizializza le 3 cache line
        for (int i = 0; i < NUM_CACHELINES; i++) {
            data[i] = i + 1;
            if (data[i] != i + 1)
                exit(i + 1);
        }

        // 2. Configura l'IP
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_0_REG_OFFSET) = (uint64_t)&data[0];
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_1_REG_OFFSET) = (uint64_t)&data[1];
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_2_REG_OFFSET) = (uint64_t)&data[2];

        // 3. Setta valid
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_VALID_REG_OFFSET) = 0x7;

        // 4. Boom! Start
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_START_REG_OFFSET) = 1;

        // 5. ATTESA SOFTWARE
        for (volatile int delay = 0; delay < 5000; delay++) {
            __asm__ volatile ("nop");
        }
        
        // Barriera: Assicura che tutto ciò che è successo prima sia visibile in RAM
        // prima di scrivere la flag di sincronizzazione.
        __asm__ volatile ("fence rw, rw" ::: "memory");

        // 6. SBLOCCA IL CORE 1
        sync_flag = 1; 
    }

    // ==========================================
    // CORE 1: Il Lettore (Aspetta e verifica)
    // ==========================================
    else if (cid == 1) {
        
        // 1. BARRIERA DI ATTESA (Spinlock)
        while (sync_flag == 0) {
            __asm__ volatile ("nop");
        }

        // 2. FENCE DI LETTURA (CRUCIALE!)
        // Assicura che le istruzioni successive leggano i dati aggiornati dalla RAM
        // solo DOPO che il blocco del while è stato superato.
        __asm__ volatile ("fence r, r" ::: "memory");
        
        // 3. VERIFICA I DATI (Non sovrascriverli!)
        for (int i = 0; i < NUM_CACHELINES; i++) {
            
           volatile uint128_t read_line = data[i];
        }
        
for (volatile int wait = 0; wait < 1000; wait++) {
            __asm__ volatile ("nop");
        }
        
        exit(0); // Ora puoi spegnere tutto.
    }
}
