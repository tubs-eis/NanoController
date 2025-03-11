// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

`define SIZE_CLUT 21
`define SIZE_SCHG 16
`define SIZE_IMEM 128

module SPI_Debug_Master(
  i_nano_clk,
  i_dbg_spi_miso,
  o_nano_rst_n,
  o_dbg_spi_en_n,
  o_dbg_spi_mosi,
  o_dbg_spi_sclk);

  parameter string app_prefix;

  input  logic i_nano_clk;
  input  logic i_dbg_spi_miso;
  output logic o_nano_rst_n;
  output logic o_dbg_spi_en_n;
  output logic o_dbg_spi_mosi;
  output logic o_dbg_spi_sclk;
  
  byte cyclelut[`SIZE_CLUT];
  shortint schg[`SIZE_SCHG];
  byte imem[`SIZE_IMEM];
  
  //
  enum {idle, data1, data2, data3, data4} spi_masterstate = idle;
  enum {cmd, readval, writeval} spi_protocolstate = cmd;
  int spi_cnt;
  int spi_pos = 7;
  int spi_tx_cnt = 0;
  parameter int spi_tx_len = 2*(`SIZE_CLUT + 2*`SIZE_SCHG + `SIZE_IMEM) + 13;
  
  byte spi_tx[spi_tx_len];
  bit spi_is_read[spi_tx_len];
  int spi_cnt_ary[spi_tx_len];
  
  int m = 0;
  int n = 0;
  int o = 0;
  
  logic [7:0] spi_tx_val;
  logic [7:0] spi_rx_data;
  
  //
  task SPISeqInit(input byte cmd, input byte dat);
    spi_tx[m++] = cmd;
    spi_tx[m++] = dat;
    spi_is_read[n++] = 1'b0;
    spi_is_read[n++] = 1'b0;
    spi_cnt_ary[o++] = 3;
    spi_cnt_ary[o++] = 3;
  endtask // SPISeqInit
  
  //
  initial begin;
    $timeformat(-6, 2, " us");
    
    // Read set of files
    $readmemb({app_prefix, ".clut"}, cyclelut);
    $readmemb({app_prefix, ".schg"}, schg);
    $readmemh({app_prefix, ".mem"}, imem);
    
    // Initialize SPI TX Sequence
    SPISeqInit(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    for (int j = 0; j < `SIZE_CLUT; j++) begin
      SPISeqInit(96, cyclelut[j]);  // Configure Cycle LUT (command 96)
    end
    SPISeqInit(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    for (int j = 0; j < `SIZE_SCHG; j++) begin
      SPISeqInit(112, schg[j] & 255);  // Configure State Change LUT LSBs (command 112 + address 0)
    end
    SPISeqInit(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    for (int j = 0; j < `SIZE_SCHG; j++) begin
      SPISeqInit(113, (schg[j] >> 8) & 255);  // Configure State Change LUT MSBs (command 112 + address 1)
    end
    SPISeqInit(0, 1);  // Put NanoController in Reset via Debug Interface, reset debug address counters
    for (int j = 0; j < `SIZE_IMEM; j++) begin
      SPISeqInit(48, imem[j]);  // Configure IMEM content (command 48)
    end
    SPISeqInit(32, 3);  // Configure Clock Enable Generator (command 32)
    spi_tx[m++] = 0;          // Release NanoController Reset via Debug Interface
    spi_tx[m++] = 0;
    spi_tx[m++] = 144; //146; //128; //208;
    spi_is_read[n++] = 1'b0;
    spi_is_read[n++] = 1'b0;
    spi_is_read[n++] = 1'b1;
    spi_cnt_ary[o++] = 12;
    spi_cnt_ary[o++] = 12;
    spi_cnt_ary[o++] = 12;
    
    // Reset Sequence
    o_nano_rst_n = 1'b0;
    o_dbg_spi_en_n = 1'b1;
    o_dbg_spi_mosi = 1'b0;
    o_dbg_spi_sclk = 1'b0;
    
    // Remove Reset
    repeat(4) @(posedge i_nano_clk);
    o_nano_rst_n = 1'b1;
    
    spi_tx_val = spi_tx[spi_tx_cnt];
    spi_cnt = spi_cnt_ary[spi_tx_cnt];
    
    for (int i = 73728; i > 0; i--) begin
      
      // Generating SPI master
      if (!(spi_cnt--)) begin
        byte ctrlval;
        case (spi_masterstate)
          idle :
            begin
              o_dbg_spi_en_n = 1'b0;
              o_dbg_spi_mosi = spi_tx_val[spi_pos];
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
              spi_rx_data[spi_pos] = i_dbg_spi_miso;
              spi_masterstate = data4;
            end
            
          data4 :
            begin
              if (spi_pos--) begin
                o_dbg_spi_mosi = spi_tx_val[spi_pos];
                spi_masterstate = data1;
              end else begin
                spi_pos = 7;
                case (spi_protocolstate)
                  cmd :
                    begin
                      spi_masterstate = data1;
                      if (spi_is_read[spi_tx_cnt]) begin
                        spi_protocolstate = readval;
                      end else begin
                        spi_protocolstate = writeval;
                      end
                      $display("[SPI]  %0t: Issued command    %d", $realtime, spi_tx_val);
                      if (spi_tx_cnt < spi_tx_len - 1) begin
                        spi_tx_cnt++;
                      end
                      spi_tx_val = spi_tx[spi_tx_cnt];
                      o_dbg_spi_mosi = spi_tx_val[spi_pos];
                    end
                  
                  readval :
                    begin
                      o_dbg_spi_en_n = 1'b1;
                      o_dbg_spi_mosi = 1'b0;
                      spi_masterstate = idle;
                      spi_protocolstate = cmd;
                      ctrlval = spi_rx_data;
                      $display("[SPI]  %0t: Received value   %d", $realtime, ctrlval);
                      /*
                      $write("[NANO] %0t: Decoded CTRL     %d ( ", $realtime, ctrlval);
                      if (ctrlval & 8'h01) $write("LDO_en ");
                      if (ctrlval & 8'h02) $write("ADC_en ");
                      if (ctrlval & 8'h04) $write("Sensor1_en ");
                      if (ctrlval & 8'h08) $write("Sensor2_en ");
                      if (ctrlval & 8'h10) $write("Temp_en ");
                      if (ctrlval & 8'h20) $write("VCO_en ");
                      if (ctrlval & 8'h40) $write("TX_en ");
                      $display(")");
                      */
                    end
                  
                  writeval :
                    begin
                      o_dbg_spi_en_n = 1'b1;
                      o_dbg_spi_mosi = 1'b0;
                      spi_masterstate = idle;
                      spi_protocolstate = cmd;
                      $display("[SPI]  %0t: Transmitted value %d", $realtime, spi_tx_val);
                      if (spi_tx_cnt < spi_tx_len - 1) begin
                        spi_tx_cnt++;
                      end
                      spi_tx_val = spi_tx[spi_tx_cnt];
                    end
                endcase
              end
            end
        endcase
        spi_cnt = spi_cnt_ary[spi_tx_cnt];
      end
      
      @(posedge i_nano_clk);
    end
    
    $finish();
  end // initial
  
endmodule
