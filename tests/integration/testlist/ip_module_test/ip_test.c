#include "../../sw/include/nb_cores.h"
#include "../../sw/include/addr_table_regs.h"
#include <stdint.h>

#define ADDR_TABLE_BASE 0x50000000UL

extern void exit(int);

// 128 bit (16 Byte) corrispondono esattamente a 1 cache line nella vostra architettura
#define uint128_t __uint128_t
#define NUM_CACHELINES 3 // Riduciamo a 3 per il test del tuo modulo

// Il linker piazzerà questo array nell'indirizzo RAM corretto e cacheabile
uint128_t data[NUM_CACHELINES] __attribute__((section(".cache_share_region")));

void ip_invalidation_test(int cid) {
    
    // Lavora solo il Core 0
    if (cid == 0) {
        
        // 1. Il Core 0 inizializza le 3 cache line.
        // Scrivendoci dentro (data[i] = i+1), il core invia una richiesta
        // alla CCU (probabilmente ReadUnique) per diventarne proprietario esclusivo.
        for (int i = 0; i < NUM_CACHELINES; i++) {
            data[i] = i + 1;
            
            // Verifica di aver scritto e letto correttamente dalla sua cache L1
            if (data[i] != i + 1)
                exit(i + 1);
        }

        // 2. Passiamo gli indirizzi fisici di queste 3 variabili al tuo modulo IP
        // Usiamo "&data[i]" per ricavare l'indirizzo esatto che il linker ha assegnato.
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_0_REG_OFFSET) = (uint64_t)&data[0];
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_1_REG_OFFSET) = (uint64_t)&data[1];
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DATA_2_REG_OFFSET) = (uint64_t)&data[2];

        // 3. Setta i bit valid (0b0111 = 7) per indicare che le prime 3 entry sono valide
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_VALID_REG_OFFSET) = 0x7;

        // (Opzionale) Mettiamo una fence di sicurezza per assicurarci che i registri 
        // sopra siano stati scritti sul bus prima di dare lo START.
        asm volatile("fence" ::: "memory");

        // 4. Boom! Diamo il via alla FSM del modulo hardware
        *(volatile uint64_t*)(ADDR_TABLE_BASE + ADDR_TABLE_START_REG_OFFSET) = 1;
    }
}