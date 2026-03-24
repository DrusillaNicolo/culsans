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
#define ADDR_TABLE_PARAM_REG_WIDTH 64

// Entry register (common parameters)
#define ADDR_TABLE_DATA_DATA_FIELD_WIDTH 64
#define ADDR_TABLE_DATA_DATA_FIELDS_PER_REG 1
#define ADDR_TABLE_DATA_MULTIREG_COUNT 4

// Entry register
#define ADDR_TABLE_DATA_0_REG_OFFSET 0x0

// Entry register
#define ADDR_TABLE_DATA_1_REG_OFFSET 0x8

// Entry register
#define ADDR_TABLE_DATA_2_REG_OFFSET 0x10

// Entry register
#define ADDR_TABLE_DATA_3_REG_OFFSET 0x18

// Valid bit for entry N (common parameters)
#define ADDR_TABLE_VALID_VALID_FIELD_WIDTH 1
#define ADDR_TABLE_VALID_VALID_FIELDS_PER_REG 64
#define ADDR_TABLE_VALID_MULTIREG_COUNT 1

// Valid bit for entry N
#define ADDR_TABLE_VALID_REG_OFFSET 0x20
#define ADDR_TABLE_VALID_VALID_0_BIT 0
#define ADDR_TABLE_VALID_VALID_1_BIT 1
#define ADDR_TABLE_VALID_VALID_2_BIT 2
#define ADDR_TABLE_VALID_VALID_3_BIT 3

// When core0 finishes to fill the add table, we set this reg and we start
// with the invalidation process
#define ADDR_TABLE_START_REG_OFFSET 0x28
#define ADDR_TABLE_START_START_BIT 0

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _ADDR_TABLE_REG_DEFS_
// End generated register defines for addr_table