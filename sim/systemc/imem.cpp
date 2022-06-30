// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#include "include/imem.hpp"

void imem_ref::func() {
  while(true) {
    wait();
    if(imem_oe.read() == '1') {
      unsigned int tmp_addr = imem_addr.read().to_uint();
      if(tmp_addr < (sizeof(imem_image)/sizeof(imem_image[0]))) 
        imem_out.write(imem_image[tmp_addr]);
      else
        SC_REPORT_FATAL("imem", "[ERROR] imem_image Address Overflow. Stopping.");
    }
  }
}
