// #################################################################################################
// # << NEORV32: neorv32_plam.c - General Purpose Input/Output Port HW Driver (Source) >>          #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
// #################################################################################################

/**********************************************************************/ /**
 * @file neorv32_plam.c
 * @author Stephan Nolting
 * @brief General purpose input/output port unit (plam) HW driver source file.
 *
 * @note These functions should only be used if the plam unit was synthesized (IO_plam_EN = true).
 **************************************************************************/

#include "neorv32.h"
#include "neorv32_plam.h"

/**********************************************************************/ /**
 * Check if plam unit was synthesized.
 *
 * @return 0 if plam was not synthesized, 1 if plam is available.
 **************************************************************************/
int neorv32_plam_available(void)
{

  if (SYSINFO_FEATURES & (1 << SYSINFO_FEATURES_IO_PLAM))
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

/**********************************************************************/ /**
 * Set complete plam output port.
 *
 * @param[in] port_data New output port value (64-bit).
 **************************************************************************/
void neorv32_plam_port_set(uint32_t port_data)
{

  PLAM_INPUT = port_data;
}

/**********************************************************************/ /**
 * Get complete plam input port.
 *
 * @return Current input port state (64-bit).
 **************************************************************************/
uint32_t neorv32_plam_port_get(void)
{

  return PLAM_OUTPUT;
}
