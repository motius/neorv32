// #################################################################################################
// # << NEORV32: neorv32_crc32.c - Cyclic Redundancy Check (CRC32) HW Driver        >>             #
// # ********************************************************************************************* #

/**********************************************************************//**
 * @file neorv32_crc32.c
 * @author Kevin Bello
 * @brief Cyclic Redundancy Check (CRC32) HW driver header file.
 * 
 * @note These functions should only be used if the CRC32 was synthesized (IO_CRC32_EN = true).
 **************************************************************************/

#include "neorv32.h"
#include "neorv32_crc32.h"


/**********************************************************************//**
 * Check if custom functions unit 0 was synthesized.
 *
 * @return 0 if CRC32 was not synthesized, 1 if CRC32 is available.
 **************************************************************************/
int neorv32_crc32_available(void) {

  if (SYSINFO_FEATURES & (1 << SYSINFO_FEATURES_IO_CRC32)) {
    return 1;
  }
  else {
    return 0;
  }
}

/**********************************************************************//**
 * Cyclic Redundancy Check (CRC32)
 *
 * @return Current input port state (32-bit).
 **************************************************************************/
uint32_t neorv32_crc32(const char *s) {

uint32_t result = 0;
CRC32_OUTPUT = 0xFFFFFFFF;
  char c = 0;
  while ((c = *s++)) {
    CRC32_INPUT = (0x000000FF & c);
    result = ~CRC32_OUTPUT;
    CRC32_OUTPUT = CRC32_OUTPUT;
  }
  return result;
}
