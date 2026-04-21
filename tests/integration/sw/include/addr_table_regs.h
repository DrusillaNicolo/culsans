// Generated register defines for addr_table

// Copyright information found in source file:
// Copyright EPFL contributors.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _ADDR_TABLE_REG_DEFS_
#define _ADDR_TABLE_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define ADDR_TABLE_PARAM_REG_WIDTH 32

// Start address of the entry (common parameters)
#define ADDR_TABLE_START_ADDR_START_ADDR_FIELD_WIDTH 32
#define ADDR_TABLE_START_ADDR_START_ADDR_FIELDS_PER_REG 1
#define ADDR_TABLE_START_ADDR_MULTIREG_COUNT 4

// Start address of the entry
#define ADDR_TABLE_START_ADDR_0_REG_OFFSET 0x0

// Start address of the entry
#define ADDR_TABLE_START_ADDR_1_REG_OFFSET 0x4

// Start address of the entry
#define ADDR_TABLE_START_ADDR_2_REG_OFFSET 0x8

// Start address of the entry
#define ADDR_TABLE_START_ADDR_3_REG_OFFSET 0xc

// End address of the entry (common parameters)
#define ADDR_TABLE_END_ADDR_END_ADDR_FIELD_WIDTH 32
#define ADDR_TABLE_END_ADDR_END_ADDR_FIELDS_PER_REG 1
#define ADDR_TABLE_END_ADDR_MULTIREG_COUNT 4

// End address of the entry
#define ADDR_TABLE_END_ADDR_0_REG_OFFSET 0x10

// End address of the entry
#define ADDR_TABLE_END_ADDR_1_REG_OFFSET 0x14

// End address of the entry
#define ADDR_TABLE_END_ADDR_2_REG_OFFSET 0x18

// End address of the entry
#define ADDR_TABLE_END_ADDR_3_REG_OFFSET 0x1c

// Valid bit for entry N (common parameters)
#define ADDR_TABLE_VALID_VALID_FIELD_WIDTH 32
#define ADDR_TABLE_VALID_VALID_FIELDS_PER_REG 1
#define ADDR_TABLE_VALID_MULTIREG_COUNT 4

// Valid bit for entry N
#define ADDR_TABLE_VALID_0_REG_OFFSET 0x20

// Valid bit for entry N
#define ADDR_TABLE_VALID_1_REG_OFFSET 0x24

// Valid bit for entry N
#define ADDR_TABLE_VALID_2_REG_OFFSET 0x28

// Valid bit for entry N
#define ADDR_TABLE_VALID_3_REG_OFFSET 0x2c

// Dirty bit for entry N (common parameters)
#define ADDR_TABLE_DIRTY_DIRTY_FIELD_WIDTH 32
#define ADDR_TABLE_DIRTY_DIRTY_FIELDS_PER_REG 1
#define ADDR_TABLE_DIRTY_MULTIREG_COUNT 4

// Dirty bit for entry N
#define ADDR_TABLE_DIRTY_0_REG_OFFSET 0x30

// Dirty bit for entry N
#define ADDR_TABLE_DIRTY_1_REG_OFFSET 0x34

// Dirty bit for entry N
#define ADDR_TABLE_DIRTY_2_REG_OFFSET 0x38

// Dirty bit for entry N
#define ADDR_TABLE_DIRTY_3_REG_OFFSET 0x3c

// Shared bit for entry N (common parameters)
#define ADDR_TABLE_SHARED_SHARED_FIELD_WIDTH 32
#define ADDR_TABLE_SHARED_SHARED_FIELDS_PER_REG 1
#define ADDR_TABLE_SHARED_MULTIREG_COUNT 4

// Shared bit for entry N
#define ADDR_TABLE_SHARED_0_REG_OFFSET 0x40

// Shared bit for entry N
#define ADDR_TABLE_SHARED_1_REG_OFFSET 0x44

// Shared bit for entry N
#define ADDR_TABLE_SHARED_2_REG_OFFSET 0x48

// Shared bit for entry N
#define ADDR_TABLE_SHARED_3_REG_OFFSET 0x4c

// When core0 finishes to fill the add table, we set this reg and we start
// with the invalidation process
#define ADDR_TABLE_START_REG_OFFSET 0x50
#define ADDR_TABLE_START_START_BIT 0

// Flag indicating the end of the invalidation process
#define ADDR_TABLE_END_FLAG_REG_OFFSET 0x54
#define ADDR_TABLE_END_FLAG_END_FLAG_BIT 0

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _ADDR_TABLE_REG_DEFS_
// End generated register defines for addr_table