// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#include "include/imem.hpp"

int imem_ref::min(int a, int b) {
	return (a < b) ? a : b;
}

void imem_ref::func() {
  unsigned int tmp_addr = imem_addr.read().to_uint();
  
  if(tmp_addr < (sizeof(imem_image)/sizeof(imem_image[0]))) 
    imem_out.write(imem_image[tmp_addr]);
}

void imem_ref::addrchk() {
  while(true) {
    wait();
    unsigned int tmp_addr = imem_addr.read().to_uint();
  }
}
