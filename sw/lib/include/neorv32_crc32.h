// #################################################################################################
// # << NEORV32: neorv32_crc32.h - Cyclic Redundancy Check (CRC32) HW Driver (stub) >>             #
// # ********************************************************************************************* #

/**********************************************************************//**
 * @file neorv32_crc32.h
 * @author Kevin Bello
 * @brief Cyclic Redundancy Check (CRC32) HW driver header file.
 * *
 * @note These functions should only be used if the CRC32 was synthesized (IO_CRC32_EN = true).
 **************************************************************************/

#ifndef neorv32_crc32_h
#define neorv32_crc32_h

// prototypes
int neorv32_crc32_available(void);
uint32_t neorv32_crc32(const char *s);

#endif // neorv32_crc32_h
