///////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
///////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:
///////////////////////////////////////////////////////////////////////////////
module remote_updata_top
#(
parameter FPGA_VESION           = 48'h2025_0315_1939,   // year,month,day,hour,minute;
parameter DEVICE                = "PGL50H"          ,   // "PGL12G":bitstream 518KB;  "PGL22G":bitstream 746KB;  "PGL25G":bitstream 982KB; "PGL50H":bitstream 2053KB; "PGL100H":bitstream 4059KB;
parameter USER_BITSTREAM_CNT    = 2'd3              ,   // user bitstream count,2'd1,2'd2,2'd3 ----> there are 1/2/3 user bitstream in the flash,at least 1 bitstream.
parameter USER_BITSTREAM1_ADDR  = 24'h20_3000       ,   // user bitstream1 start address  ---> [2*4KB+748KB(746),32MB- 748KB(746)],4KB align  // 24'hb_d000
parameter USER_BITSTREAM2_ADDR  = 24'h28_3000       ,   // user bitstream2 start address  
parameter USER_BITSTREAM3_ADDR  = 24'h30_3000           // user bitstream3 start address  
)(
input               pin_clk_in              ,
input               sys_rst_n               ,
//-------------------------------------------------
input               uart_rx                 ,
output              uart_tx                 ,

output  [7:0]       led                     ,
//-------------------------------------------------
output              spi_cs                  ,
output              spi_clk                 ,
input               spi_dq1                 ,
output              spi_dq0                  
);
//-----------------------------------------------------------
wire      [7:0]     rx_data                 ;
wire                rx_valid                ;
      
wire      [7:0]     tx_data                 ;
wire                tx_valid                ;
wire                tx_ready                ;

wire                flash_rd_en             ;
wire                flash_wr_en             ;

wire                spi_status_rd_en        ;
wire        [7:0]   spi_status_erorr        ;

wire                flash_cfg_cmd_en        ;
wire        [7:0]   flash_cfg_cmd           ;
wire        [15:0]  flash_cfg_reg_wrdata    ;
wire                flash_cfg_reg_rd_en     ;
wire        [15:0]  flash_cfg_reg_rddata    ;

wire        [7:0]   flash_rd_data           ;
wire                flash_rd_valid          ;
wire                flash_rd_data_fifo_afull;

wire        [31:0]  bs_readback_crc         ;
wire                bs_readback_crc_valid   ;

wire                open_sw_code_done       ;
wire                bitstream_wr_done       ;
wire                bitstream_rd_done       ;
wire        [1:0]   bitstream_wr_num        ;
wire        [1:0]   bitstream_rd_num        ;
      
wire                bitstream_fifo_rd_req   ;
wire        [7:0]   bitstream_data          ;
wire                bitstream_valid         ;
wire                bitstream_eop           ;
wire                bitstream_fifo_rd_rdy   ;

wire                pll_lock                ;
wire                sys_clk                 ;
wire                sys_clk_25m             ;
wire                clear_bs_done           ;
wire                clear_sw_done           ;

wire        [1:0]   bs_crc32_ok             ;//[1]:valid   [0]:1'b0,OK  1'b1,error
wire                write_sw_code_en        ;
wire                bitstream_up2cpu_en     ;
wire                crc_check_en            ;
wire                clear_sw_en             ;
wire                hotreset_en             ;
wire        [1:0]   open_sw_num             ;
wire                ipal_busy               ;

//debug
reg         [7:0]   led_reg                 ;
reg         [25:0]  led_cnt                 ;
wire        [15:0]  flash_flag_status       ;
wire                time_out_reg            ;
//-----------------------------------------------------------
assign led  = led_reg   ;

always @ (posedge sys_clk_25m or negedge sys_rst_n)
begin
    if (sys_rst_n==1'b0)     
        led_cnt <= 26'h0; 
    else
        led_cnt <= led_cnt + 1'b1; 
end

always @ (posedge sys_clk_25m or negedge sys_rst_n)
begin
    if (sys_rst_n==1'b0)     
        led_reg <= 8'h0; 
    else
        led_reg <= {{4{led_cnt[25]}},{4{led_cnt[24]}}}; 
end

//-----------------------------------------------------------

pll u_pll(
  .clkin1                       (pin_clk_in                 ),// 50Mhz
  .pll_lock                     (pll_lock                   ),
  .clkout0                      (sys_clk                    ),// 50Mhz
  .clkout1                      (sys_clk_25m                ) // 25Mhz
);

uart_top #(
    .CLK_DIV                    (12'd217                    ) // 25Mhz 
) u_uart_top(
    .sys_clk                    (sys_clk_25m                ),
    .sys_rst_n                  (sys_rst_n                  ),

    .rx_data                    (rx_data                    ),
    .rx_valid                   (rx_valid                   ),

    .tx_data                    (tx_data                    ),
    .tx_valid                   (tx_valid                   ),
    .tx_ready                   (tx_ready                   ),

    .uart_rx                    (uart_rx                    ),
    .uart_tx                    (uart_tx                    )
);

//--------------------------------------------------------------------------
// clear is 4KB align , so the bitstream write data is 4KB align 
//--------------------------------------------------------------------------
data_ctrl#(
    .FPGA_VESION                (FPGA_VESION                ),  
    .USER_BITSTREAM_CNT         (USER_BITSTREAM_CNT         ),
    .USER_BITSTREAM1_ADDR       (USER_BITSTREAM1_ADDR       ),
    .USER_BITSTREAM2_ADDR       (USER_BITSTREAM2_ADDR       ),
    .USER_BITSTREAM3_ADDR       (USER_BITSTREAM3_ADDR       )
)
u_data_ctrl
(
    .sys_clk                    (sys_clk_25m                ),
    .sys_rst_n                  (sys_rst_n                  ),

    .rx_data                    (rx_data                    ),
    .rx_valid                   (rx_valid                   ),

    .tx_data                    (tx_data                    ),
    .tx_valid                   (tx_valid                   ),
    .tx_ready                   (tx_ready                   ),

    .flash_rd_en                (flash_rd_en                ),
    .flash_wr_en                (flash_wr_en                ),
    .bitstream_wr_num           (bitstream_wr_num           ),
    .bitstream_rd_num           (bitstream_rd_num           ),
    .bs_crc32_ok                (bs_crc32_ok                ),
    .write_sw_code_en           (write_sw_code_en           ),
    .bitstream_up2cpu_en_out    (bitstream_up2cpu_en        ),
    .crc_check_en_out           (crc_check_en               ),
    .clear_sw_en_out            (clear_sw_en                ),
    .hotreset_en                (hotreset_en                ),
    .open_sw_num_out            (open_sw_num                ),

    .spi_status_rd_en           (spi_status_rd_en           ),
    .spi_status_erorr           (spi_status_erorr           ),
    .flash_flag_status          (flash_flag_status          ),
    .time_out_reg               (time_out_reg               ),

    .flash_cfg_cmd_en           (flash_cfg_cmd_en           ),
    .flash_cfg_cmd              (flash_cfg_cmd              ),
    .flash_cfg_reg_wrdata       (flash_cfg_reg_wrdata       ),
    .flash_cfg_reg_rd_en        (flash_cfg_reg_rd_en        ),
    .flash_cfg_reg_rddata       (flash_cfg_reg_rddata       ),

    .flash_rd_data              (flash_rd_data              ),
    .flash_rd_valid             (flash_rd_valid             ),
    .flash_rd_data_fifo_afull   (flash_rd_data_fifo_afull   ),

    .bs_readback_crc            (bs_readback_crc            ),
    .bs_readback_crc_valid      (bs_readback_crc_valid      ),
    
    .ipal_busy                  (ipal_busy                  ),
    .clear_sw_done              (clear_sw_done              ),
    .clear_bs_done              (clear_bs_done              ),
    .bitstream_wr_done          (bitstream_wr_done          ),
    .bitstream_rd_done          (bitstream_rd_done          ),
    .open_sw_code_done          (open_sw_code_done          ),

    .bitstream_fifo_rd_req      (bitstream_fifo_rd_req      ),
    .bitstream_data             (bitstream_data             ),
    .bitstream_valid            (bitstream_valid            ),
    .bitstream_eop              (bitstream_eop              ),
    .bitstream_fifo_rd_rdy      (bitstream_fifo_rd_rdy      )
);


//-----------------------------------------------------------
spi_top
#(
    .DEVICE                     (DEVICE                     ), 
    .USER_BITSTREAM_CNT         (USER_BITSTREAM_CNT         ),
    .USER_BITSTREAM1_ADDR       (USER_BITSTREAM1_ADDR       ),
    .USER_BITSTREAM2_ADDR       (USER_BITSTREAM2_ADDR       ),
    .USER_BITSTREAM3_ADDR       (USER_BITSTREAM3_ADDR       )                 
)
u_spi_top
(
    .sys_clk                    (sys_clk_25m                ),
    .sys_rst_n                  (sys_rst_n                  ),
 
    .spi_cs                     (spi_cs                     ),
    .spi_clk                    (spi_clk                    ),
    .spi_dq1                    (spi_dq1                    ),
    .spi_dq0                    (spi_dq0                    ),
// ctrl
    .flash_wr_en                (flash_wr_en                ),
    .flash_rd_en                (flash_rd_en                ),
    .bitstream_wr_num           (bitstream_wr_num           ),
    .bitstream_rd_num           (bitstream_rd_num           ),
    .bitstream_up2cpu_en        (bitstream_up2cpu_en        ),
    .crc_check_en               (crc_check_en               ),
    .clear_sw_en                (clear_sw_en                ),
    .bs_crc32_ok                (bs_crc32_ok                ),
    .write_sw_code_en           (write_sw_code_en           ),
// debug 
    .flash_flag_status          (flash_flag_status          ),
    .time_out_reg               (time_out_reg               ),

    .flash_cfg_cmd_en           (flash_cfg_cmd_en           ),
    .flash_cfg_cmd              (flash_cfg_cmd              ),
    .flash_cfg_reg_wrdata       (flash_cfg_reg_wrdata       ),
    .flash_cfg_reg_rd_en        (flash_cfg_reg_rd_en        ),
    .flash_cfg_reg_rddata       (flash_cfg_reg_rddata       ),
// read bitstream 
    .flash_rd_data_o            (flash_rd_data              ),
    .flash_rd_valid_o           (flash_rd_valid             ),
    .flash_rd_data_fifo_afull   (flash_rd_data_fifo_afull   ),
// readback_crc & done
    .bs_readback_crc            (bs_readback_crc            ),
    .bs_readback_crc_valid      (bs_readback_crc_valid      ),
    
    .clear_sw_done              (clear_sw_done              ),
    .clear_bs_done              (clear_bs_done              ),
    .bitstream_wr_done          (bitstream_wr_done          ),
    .bitstream_rd_done          (bitstream_rd_done          ),
    .open_sw_code_done          (open_sw_code_done          ),
// write bitstream
    .bitstream_fifo_rd_req      (bitstream_fifo_rd_req      ),
    .bitstream_data             (bitstream_data             ),
    .bitstream_valid            (bitstream_valid            ),
    .bitstream_eop              (bitstream_eop              ),
    .bitstream_fifo_rd_rdy      (bitstream_fifo_rd_rdy      )
);


ipal_ctrl#(
    .USER_BITSTREAM_CNT         (USER_BITSTREAM_CNT         ),
    .USER_BITSTREAM1_ADDR       (USER_BITSTREAM1_ADDR       ),
    .USER_BITSTREAM2_ADDR       (USER_BITSTREAM2_ADDR       ),
    .USER_BITSTREAM3_ADDR       (USER_BITSTREAM3_ADDR       )
) 
u_ipal_ctrl(
    .sys_clk                    (sys_clk_25m                ),
    .sys_rst_n                  (sys_rst_n                  ),

    .open_sw_num                (open_sw_num                ),
    .ipal_busy                  (ipal_busy                  ),
    .crc_check_en               (crc_check_en               ),
    .bs_crc32_ok                (bs_crc32_ok                ),
    .hotreset_en                (hotreset_en                ),
    .open_sw_code_done          (open_sw_code_done          )
);
endmodule
