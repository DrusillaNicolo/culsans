#include "../../sw/include/nb_cores.h"
#include "../../sw/include/addr_table_regs.h"
#include <stdint.h>

#define ADDR_TABLE_BASE 0x50000000UL
extern void exit(int);

#define uint128_t __uint128_t
#define NUM_CACHELINES 10 

volatile uint128_t data[NUM_CACHELINES] __attribute__((section(".cache_share_region")));
volatile uint32_t sync_flag __attribute__((section(".cache_share_region"))) = 0; 

void ip_invalidation_test(int cid) {
  
    if (cid == 0) {
        
        // 1. Inizializzazione dei dati
        for (int i = 0; i < NUM_CACHELINES; i++) {
            data[i] = i + 1;
            if (data[i] != i + 1)
                exit(i + 1);
        }

        // 2. Configurazione dei registri dell'IP
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_START_ADDR_0_REG_OFFSET) = (uint32_t)(uintptr_t)&data[0];
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_END_ADDR_0_REG_OFFSET) = (uint32_t)(uintptr_t)&data[NUM_CACHELINES - 1];
        
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_VALID_0_REG_OFFSET) = 1;
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_DIRTY_0_REG_OFFSET) = 1;
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_SHARED_0_REG_OFFSET) = 1;
        
        // 3. LANCIO L'IP
        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_START_REG_OFFSET) = 1;

        // ========================================================
        // FIX SOLUZIONE 1: Polling "che respira" (No starvation)
        // ========================================================
        while (*(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_END_FLAG_REG_OFFSET) == 0) {
         
            /*
            // Faccio respirare il bus AXI per 50 cicli
            for (volatile int j = 0; j < 50; j++) {
                __asm__ volatile ("nop");
            }
            */
            // Forzo il Core a rileggere fisicamente dal bus AXI (ignora la Cache L1)
            __asm__ volatile ("fence io, io" ::: "memory");
        }

        *(volatile uint32_t*)(ADDR_TABLE_BASE + ADDR_TABLE_END_FLAG_REG_OFFSET) = 0; 
        // ========================================================

        // 4. Sincronizzazione con il Core 1
        __asm__ volatile ("fence rw, rw" ::: "memory");
        sync_flag = 1; // Sblocco il Core 1

        // 5. Handshake di chiusura: aspetto che il Core 1 finisca di leggere
        while (sync_flag != 2) {
            __asm__ volatile ("nop");
        }
        // Ora il Core 0 esce e la simulazione termina in modo sicuro.
    }

    else if (cid == 1) {
        
        // 1. Aspetto che il Core 0 mi dia il via libera (invalidazione completata)
        while (sync_flag == 0) {
            __asm__ volatile ("nop");
        }

        __asm__ volatile ("fence r, r" ::: "memory");
        
        // 2. Il Core 1 fa le letture (subendo i miss in cache causati dal nostro IP!)
        for (int i = 0; i < NUM_CACHELINES; i++) {
             uint128_t read_line = data[i];
             (void)read_line;
        }
        
        __asm__ volatile ("fence rw, rw" ::: "memory");
        
        // 3. Handshake di chiusura: dico al Core 0 che ho finito
        sync_flag = 2;
        
        // Piccolo ritardo di sicurezza prima della exit per far assestare i bus
        for (volatile int wait = 0; wait < 1000; wait++) {
            __asm__ volatile ("nop");
        }
        
        exit(0);
    }
}