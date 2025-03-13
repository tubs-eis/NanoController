// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

module testbench(
  i_nano_clk,
  i_nano_sleep_golden, i_nano_sleep_dut,
  i_nano_func_golden, i_nano_func_dut,
  o_nano_rst_n,
  o_dbg_spi_en_n,
  o_dbg_spi_mosi_golden, o_dbg_spi_mosi_dut,
  o_dbg_spi_sclk
);

  parameter NANO_FUNC_OUTS_C = 8;
  parameter NANO_IRQ_W_C = 4;
  parameter NANO_D_W_C = 9;
  parameter string goldenref = "";
  parameter string dutfiles = "";
  parameter string lutidx = "";
  parameter SIZE_CLUT = 21;
  parameter SIZE_SCHG = 16;
  parameter SIZE_IMEM = 128;

  input  logic i_nano_clk;
  input  logic i_nano_sleep_golden, i_nano_sleep_dut;
  input  logic [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] i_nano_func_golden, i_nano_func_dut;
  output logic o_nano_rst_n;
  output logic o_dbg_spi_en_n;
  output logic o_dbg_spi_mosi_golden, o_dbg_spi_mosi_dut;
  output logic o_dbg_spi_sclk;
  
  byte cyclelut_golden[SIZE_CLUT], cyclelut_dut[SIZE_CLUT];
  shortint schg_golden[SIZE_SCHG], schg_dut[SIZE_SCHG];
  byte imem_golden[SIZE_IMEM], imem_dut[SIZE_IMEM];
  
  logic nano_sleep_golden_prev = 0;
  logic nano_sleep_dut_prev = 0;
  logic [(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C-1:0] nano_func_golden_queue [$];
  logic [(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C-1:0] nano_func_dut_queue [$];
  
  //
  enum {idle, data1, data2, data3, data4} spi_masterstate = idle;
  enum {cmd, writeval} spi_protocolstate = cmd;
  int spi_cnt;
  int spi_pos = 7;
  int spi_tx_cnt = 0;
  parameter int spi_tx_len = 2*(SIZE_CLUT + 2*SIZE_SCHG + SIZE_IMEM) + 12;
  
  byte spi_tx_golden[spi_tx_len], spi_tx_dut[spi_tx_len];
  
  int m = 0, p = 0;
  
  logic [7:0] spi_tx_val_golden, spi_tx_val_dut;
  
  //
  task SPISeqInitGolden(input byte cmd, input byte dat);
    spi_tx_golden[m++] = cmd;
    spi_tx_golden[m++] = dat;
  endtask // SPISeqInitGolden
  
  task SPISeqInitDUT(input byte cmd, input byte dat);
    spi_tx_dut[p++] = cmd;
    spi_tx_dut[p++] = dat;
  endtask // SPISeqInitDUT
  
  //
  initial begin;
    
    $timeformat(-6, 2, " us");
    
    // Read set of files for Golden Reference
    $readmemb({goldenref, ".clut"}, cyclelut_golden);
    $readmemb({goldenref, ".schg"}, schg_golden);
    $readmemh({goldenref, ".mem"}, imem_golden);
    
    // Read set of files for DUT
    $readmemb({dutfiles, lutidx, ".clut"}, cyclelut_dut);
    $readmemb({dutfiles, lutidx, ".schg"}, schg_dut);
    $readmemh({dutfiles, ".mem"}, imem_dut);
    
    // Initialize SPI TX Sequence
    SPISeqInitGolden(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    SPISeqInitDUT(0, 1);
    for (int j = 0; j < SIZE_CLUT; j++) begin
      SPISeqInitGolden(96, cyclelut_golden[j]);  // Configure Cycle LUT (command 96)
      SPISeqInitDUT(96, cyclelut_dut[j]);
    end
    SPISeqInitGolden(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    SPISeqInitDUT(0, 1);
    for (int j = 0; j < SIZE_SCHG; j++) begin
      SPISeqInitGolden(112, schg_golden[j] & 255);  // Configure State Change LUT LSBs (command 112 + address 0)
      SPISeqInitDUT(112, schg_dut[j] & 255);
    end
    SPISeqInitGolden(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    SPISeqInitDUT(0, 1);
    for (int j = 0; j < SIZE_SCHG; j++) begin
      SPISeqInitGolden(113, (schg_golden[j] >> 8) & 255);  // Configure State Change LUT MSBs (command 112 + address 1)
      SPISeqInitDUT(113, (schg_dut[j] >> 8) & 255);
    end
    SPISeqInitGolden(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    SPISeqInitDUT(0, 1);
    for (int j = 0; j < SIZE_IMEM; j++) begin
      SPISeqInitGolden(48, imem_golden[j]);  // Configure IMEM content (command 48)
      SPISeqInitDUT(48, imem_dut[j]);
    end
    SPISeqInitGolden(32, 3);  // Configure Clock Enable Generator (command 32)
    SPISeqInitDUT(32, 3);
    SPISeqInitGolden(0, 0);   // Release NanoController Reset via Debug Interface
    SPISeqInitDUT(0, 0);
  
    // Reset Sequence
    o_nano_rst_n = 1'b0;
    o_dbg_spi_en_n = 1'b1;
    o_dbg_spi_mosi_golden = 1'b0;
    o_dbg_spi_mosi_dut = 1'b0;
    o_dbg_spi_sclk = 1'b0;
    
    // Remove Reset
    repeat(4) @(posedge i_nano_clk);
    o_nano_rst_n = 1'b1;
    
    spi_tx_val_golden = spi_tx_golden[spi_tx_cnt];
    spi_tx_val_dut = spi_tx_dut[spi_tx_cnt];
    spi_cnt = 3;
    
    for (int i = 278528; i > 0; i--) begin
      
      // Generating SPI master
      if (!(spi_cnt--) && (spi_tx_cnt < spi_tx_len)) begin
        case (spi_masterstate)
          idle :
            begin
              o_dbg_spi_en_n = 1'b0;
              o_dbg_spi_mosi_golden = spi_tx_val_golden[spi_pos];
              o_dbg_spi_mosi_dut = spi_tx_val_dut[spi_pos];
              spi_masterstate = data1;
            end
            
          data1 :
            begin
              o_dbg_spi_sclk = 1'b1;
              spi_masterstate = data2;
            end
            
          data2 :
            begin
              spi_masterstate = data3;
            end
            
          data3 :
            begin
              o_dbg_spi_sclk = 1'b0;
              spi_masterstate = data4;
            end
            
          data4 :
            begin
              if (spi_pos--) begin
                o_dbg_spi_mosi_golden = spi_tx_val_golden[spi_pos];
                o_dbg_spi_mosi_dut = spi_tx_val_dut[spi_pos];
                spi_masterstate = data1;
              end else begin
                spi_pos = 7;
                case (spi_protocolstate)
                  cmd :
                    begin
                      spi_masterstate = data1;
                      spi_protocolstate = writeval;
                      $display("[SPI]    %0t: Issued command    %d / %d", $realtime, spi_tx_val_golden, spi_tx_val_dut);
                      spi_tx_cnt++;
                      if (spi_tx_cnt < spi_tx_len) begin
                        spi_tx_val_golden = spi_tx_golden[spi_tx_cnt];
                        spi_tx_val_dut = spi_tx_dut[spi_tx_cnt];
                      end
                      o_dbg_spi_mosi_golden = spi_tx_val_golden[spi_pos];
                      o_dbg_spi_mosi_dut = spi_tx_val_dut[spi_pos];
                    end
                  
                  writeval :
                    begin
                      o_dbg_spi_en_n = 1'b1;
                      o_dbg_spi_mosi_golden = 1'b0;
                      o_dbg_spi_mosi_dut = 1'b0;
                      spi_masterstate = idle;
                      spi_protocolstate = cmd;
                      $display("[SPI]    %0t: Transmitted value %d / %d", $realtime, spi_tx_val_golden, spi_tx_val_dut);
                      spi_tx_cnt++;
                      if (spi_tx_cnt < spi_tx_len) begin
                        spi_tx_val_golden = spi_tx_golden[spi_tx_cnt];
                        spi_tx_val_dut = spi_tx_dut[spi_tx_cnt];
                      end
                    end
                endcase
              end
            end
        endcase
        spi_cnt = 3;
      end
      
      nano_sleep_golden_prev = i_nano_sleep_golden;
      nano_sleep_dut_prev = i_nano_sleep_dut;
      
      @(posedge i_nano_clk);
      
      if (i_nano_sleep_golden && !nano_sleep_golden_prev) begin
        nano_func_golden_queue.push_back(i_nano_func_golden[(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C-1:0]);
        $write("[GOLDEN] %0t: ", $realtime);
        for (int j=(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)-1; j>=0; j--) begin
          $write("%3d ", i_nano_func_golden[j*NANO_D_W_C +: NANO_D_W_C]);
        end
        $display();
      end
      if (i_nano_sleep_dut && !nano_sleep_dut_prev) begin
        nano_func_dut_queue.push_back(i_nano_func_dut[(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C-1:0]);
        $write("[DUT]    %0t: ", $realtime);
        for (int j=(NANO_FUNC_OUTS_C-NANO_IRQ_W_C)-1; j>=0; j--) begin
          $write("%3d ", i_nano_func_dut[j*NANO_D_W_C +: NANO_D_W_C]);
        end
        $display();
      end
      
    end
    
    if ((nano_func_golden_queue.size() >= 128) && (nano_func_dut_queue.size() >= 128)) begin
      if (nano_func_golden_queue[0:127] === nano_func_dut_queue[0:127]) begin
        $finish();
      end
    end
    
    $fatal();
  
  end // initial

endmodule
