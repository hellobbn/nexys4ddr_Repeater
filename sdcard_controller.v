`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/12/2018 04:38:53 PM
// Design Name: 
// Module Name: sdcard_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sdcard_controller(
    // SD card PINs
    output reg              o_cs,           // PIN #2
    output                  o_data,         // PIN #3 Data to SD card, in the module is out
    output                  o_sclk,         // PIN #5 Clock
    input                   i_data,         // PIN #7 Data from the SD card

    // From Higher Level
    // Read
    input                   i_read_enable,  // Read Enable
    output reg [7:0]        o_read_data,    // data from SD card to higer level, so output
    output reg              o_byte_avai,    // We have read 8 bit from i_data

    // Write
    input                   i_write_enable, // Write Enable
    input [7:0]             i_data_in,      // Data to read to the SD card
    output reg              o_ready_write,  // Waiting for the [i_data_in]

    // Misc
    input                   i_reset,        // Reset the controller
    output                  o_ready,        // The card is ready
    input [31:0]            i_address,      // Write or Read address
    input                   i_clk,          // Clock from higer level
    input                   clk_100mhz,

    // DEBUG
    output [4:0]            o_status,       // DEBUG: the current state
    
    // uart
    output wire uart_txd
    );

    // Set FSM STATE
    parameter RST = 0;                      // When i_reset is enabled
    parameter INIT = 1;                     // Init the operation
    parameter CMD0 = 2;                     // CMD0 -> GO_IDLE_STATE
    parameter CMD55 = 3;                    // CMD55 -> APP_CMD
    parameter CMD41 = 4;                    // CMD41 -> Reserved
    parameter POLL_CMD = 5;
    
    // parm for read and write
    parameter IDLE = 6;
    parameter READ_BLOCK = 7;
    parameter READ_BLOCK_WAIT = 8;
    parameter READ_BLOCK_DATA = 9;
    parameter READ_BLOCK_CRC = 10;
    parameter SEND_CMD = 11;
    parameter RECEIVE_BYTE_WAITE = 12;
    parameter RECEIVE_BYTE = 13;
    parameter WRITE_BLOCK_CMD = 14;
    parameter WRITE_BLOCK_INIT = 15;
    parameter WRITE_BLOCK_DATA = 16;
    parameter WRITE_BLOCK_BYTE = 17;
    parameter WRITE_BLOCK_WAITE = 18;

    // We have 1 start bit and 2 ending bits
    parameter WRITE_DATA_SIZE = 515;

    // UART Message
    reg [7:0] sd_CMD0_message [0:15];
    reg [7:0] sd_CMD41_message [0:15];
    reg [7:0] sd_R1_message [0:15];
    
    reg [7:0] uart_tx_message;
    reg cmd0_enable;
    reg cmd41_enable;
    reg r1_enable;
    reg messageindex;
    reg cmd0_len = 8;
    reg cmd41_len = 9;
    reg r1_len = 4;
    reg whole_enable;
    wire uart_enable;
    wire uart_busy;
    
    initial begin
        cmd0_enable = 0;
        cmd41_enable = 0;
        r1_enable = 0;
        messageindex = 0;
        whole_enable = 0;
        sd_CMD0_message[0] = "[";
        sd_CMD0_message[1] = "C";
        sd_CMD0_message[2] = "M";
        sd_CMD0_message[3] = "D";
        sd_CMD0_message[4] = "0";
        sd_CMD0_message[5] = "]";
        sd_CMD0_message[6] = ":";
        sd_CMD0_message[7] = " ";
        
        sd_CMD41_message[0] = "[";
        sd_CMD41_message[1] = "C";
        sd_CMD41_message[2] = "M";
        sd_CMD41_message[3] = "D";
        sd_CMD41_message[4] = "4";
        sd_CMD41_message[5] = "1";
        sd_CMD41_message[6] = "]";
        sd_CMD41_message[7] = ":";
        sd_CMD41_message[8] = " "; 
               
        sd_R1_message[0] = "R";
        sd_R1_message[1] = "1";
        sd_R1_message[2] = "\r";
        sd_R1_message[3] = "\n";
    end
    
    always @(posedge clk_100mhz) begin
        messageindex = messageindex + 1;
        if(cmd0_enable) begin
            if(messageindex == cmd0_len) begin
                whole_enable <= 0;
            end
        end
        else if(cmd41_enable) begin
            if(messageindex == cmd41_len) begin
                whole_enable <= 0;
            end
        end
        else if(r1_enable) begin
            if(messageindex == r1_len) begin
                whole_enable <= 0;
            end
        end
        else begin
            whole_enable <= 1;
        end
    end
    
   assign uart_enable = whole_enable & (cmd0_enable | cmd41_enable | r1_enable) & (!uart_busy);
    
    always @(posedge clk_100mhz) begin
        if(cmd0_enable) begin
            uart_tx_message <= sd_CMD0_message[messageindex];
        end
        else if(cmd41_enable) begin
            uart_tx_message <= sd_CMD41_message[messageindex];
        end
        else if(r1_enable) begin
            uart_tx_message <= sd_R1_message[messageindex];
        end
    end
    
    uart_tx uart_serial(.clk(clk_100mhz), .resetn(1), .uart_txd(uart_txd), .uart_tx_busy(uart_busy), .uart_tx_en(uart_enable), .uart_tx_data(uart_tx_message));
    // ========== UART ENDS HERE =========
    
    parameter spiClk_div = 5;
    reg [4:0] state = RST;
    reg [4:0] return_state;
    reg sclk_sig = 0;
    reg [55:0] cmd_out;
    reg [7:0] recv_data;
    reg cmd_mode = 1;
    reg [7:0] data_sig = 8'hFF;

    reg [9:0] byte_counter;
    reg [9:0] bit_counter;
    reg [26:0] boot_counter = 27'd100_000_000;

    assign o_status = state;
    assign o_sclk = sclk_sig;
    assign o_data = cmd_mode ? cmd_out[55] : data_sig[7];
    assign o_ready = (state == IDLE);

    // FSM STARTS HERE
    always @(posedge i_clk) begin
        if(i_reset == 1) begin
            state <= RST;
            sclk_sig <= 0;
            boot_counter = 27'd100_000_000;
        end
        else begin
            case(state)
                RST: begin
                    if(boot_counter == 0) begin
                        sclk_sig <= 0;
                        cmd_out <= {56{1'b1}};
                        byte_counter <= 0;
                        o_byte_avai <= 0;
                        o_ready_write <= 0;
                        cmd_mode <= 1;
                        bit_counter <= 160;                 // bit count is 160 because we need to wait for some clocks (Supply Ramp up time), it is 80 spi Clock;
                        o_cs = 1;
                        state <= INIT;
                    end
                    else begin
                        boot_counter <= boot_counter - 1;
                    end
                end
                INIT: begin                                     // Wait for certain clock cycles and send CMD0
                    if(bit_counter == 0) begin
                        o_cs <= 0;
                        state <= CMD0;
                    end
                    else begin
                        bit_counter <= bit_counter - 1;
                        sclk_sig <= ~sclk_sig;
                    end
                end
                CMD0: begin
                    cmd0_enable <= 1;
                    cmd_out <= 56'hFF_40_00_00_00_00_95;
                    bit_counter <= 55;
                    return_state <= CMD55;
                    state <= SEND_CMD;
                end
                CMD55: begin
                    cmd0_enable <= 0;
                    cmd_out <= 56'hFF_77_00_00_00_00_01;        // 1111_1111_0111_0111_0000_...._0001, (A)CMD55
                    bit_counter <= 55;
                    return_state <= CMD41;
                    state <= SEND_CMD;
                end
                CMD41: begin
                    cmd41_enable <= 1;
                    cmd_out <= 56'hFF_69_00_00_00_00_01;        // 1111_1111_0110_1001_0000_...._0001, ACMD41
                    bit_counter <= 55;
                    return_state <= POLL_CMD;
                    state <= SEND_CMD;
                end
                POLL_CMD: begin  
                    cmd41_enable <= 0;                               // Check if Init succeed
                    if(recv_data[0] == 0) begin
                        state <= IDLE;
                    end
                    else begin
                        state <= CMD55;
                    end
                end
                IDLE: begin                                     // wait for command
                    if(i_read_enable == 1) begin
                        state <= READ_BLOCK;                    // Read the SD
                    end
                    else if(i_write_enable == 1) begin
                        state <= WRITE_BLOCK_CMD;               // Write the SD
                    end
                    else begin
                        state <= IDLE;                          // Waiting for the command
                    end
                end
                READ_BLOCK: begin                               // Init read command
                    cmd_out <= {16'hFF_51, i_address, 8'hFF};   // Command 1111_1111_0101_0001_..._1111_1111, CMD17, argument is the address
                    bit_counter <= 55;
                    return_state <= READ_BLOCK_WAIT;
                    state <= SEND_CMD;
                end
                READ_BLOCK_WAIT: begin                          
                    if(sclk_sig == 1 && i_data == 0) begin      // i_data = 0, in R1, means the card is not in IDLE Mode
                        byte_counter <= 511;                    // One block has 512 bytes
                        bit_counter <= 7;
                        return_state <= READ_BLOCK_DATA;
                        state <= RECEIVE_BYTE;                  // Go to receive mode
                    end
                    sclk_sig <= ~sclk_sig;
                end
                READ_BLOCK_DATA: begin
                    o_read_data <= recv_data;                   // send the data to output
                    o_byte_avai <= 1;                           // The bus is not busy now
                    if(byte_counter == 0) begin                 // IMPORTANT: We have read 511 bytes
                        bit_counter <= 7;                       // Continue receive 8 bits
                        return_state <= READ_BLOCK_CRC;         // Go read CRC
                        state <= RECEIVE_BYTE;                  // Hmmmmm
                    end
                    else begin
                        byte_counter <= byte_counter - 1;       // COntinue read data
                        return_state <= READ_BLOCK_DATA;
                        bit_counter <= 7;
                        state <= RECEIVE_BYTE;
                    end
                end
                READ_BLOCK_CRC: begin
                    bit_counter <= 7;
                    return_state <= IDLE;                       // Go back to idle, CRC7 has 7 bits and we also read the end bit
                    state <= RECEIVE_BYTE;
                end
                SEND_CMD: begin
                    if(sclk_sig == 1) begin
                        if(bit_counter == 0) begin
                            state <= RECEIVE_BYTE_WAITE;
                        end
                        else begin
                            bit_counter <= bit_counter - 1;
                            cmd_out <= {cmd_out[54:0], 1'b1};               // send the cmd
                        end
                    end
                    sclk_sig = ~sclk_sig;
                end
                RECEIVE_BYTE_WAITE: begin
                    if(sclk_sig == 1) begin
                        if(i_data == 0) begin                       // for CMD0, the correct responce is R1
                            recv_data <= 0;
                            bit_counter <= 6;                       // Receive the other 6 bits
                            state <= RECEIVE_BYTE;
                        end                                         // DO NOTHING
                    end
                    sclk_sig <= ~sclk_sig;
                end
                RECEIVE_BYTE: begin
                    o_byte_avai <= 0;                               // Set the bus to Busy
                    if(sclk_sig == 1) begin                         // Get one bit until 8 bits
                        recv_data <= {recv_data[6:0], i_data};
                        if(bit_counter == 0) begin
                            state <= return_state;                  // return
                        end
                        else begin                                  // decrease cnt
                            bit_counter <= bit_counter - 1;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
                WRITE_BLOCK_CMD: begin
                    cmd_out <= {16'hFF_58, i_address, 8'hFF};   // Command 1111_1111_0101_1000_...._1111_1111 -> CMD24, WRITE_BLOCK
                    bit_counter <= 55;
                    return_state <= WRITE_BLOCK_INIT;
                    state <= SEND_CMD;
                    o_ready_write <= 1;
                end
                WRITE_BLOCK_INIT: begin
                    cmd_mode <= 0;                              // It is not CMD Mode!
                    byte_counter <= WRITE_DATA_SIZE;            // We need to write so many bytes
                    state <= WRITE_BLOCK_DATA;
                    o_ready_write <= 0;                         // The bus is marked busy
                end
                WRITE_BLOCK_DATA: begin
                    if(byte_counter == 0) begin                 // We've done it?
                        state <= RECEIVE_BYTE_WAITE;
                        return_state <= WRITE_BLOCK_WAITE;
                    end
                    else begin
                        if((byte_counter == 2) || (byte_counter == 1)) begin
                            data_sig <= 8'hFF;                  // End Command
                        end
                        else if(byte_counter == WRITE_DATA_SIZE) begin
                            data_sig <= 8'hFE;
                        end
                        else begin
                            data_sig <= i_data_in;
                            o_ready_write <= 1;
                        end
                        bit_counter <= 7;
                        state <= WRITE_BLOCK_BYTE;
                        byte_counter <= byte_counter - 1;
                    end
                end
                WRITE_BLOCK_BYTE: begin
                    if(sclk_sig == 1) begin
                        if(bit_counter == 0) begin
                            state <= WRITE_BLOCK_DATA;          // Go for next data
                            o_ready_write <= 0;
                        end
                        else begin
                            data_sig <= {data_sig[6:0], 1'b1};  // One by one push to SD card
                            bit_counter <= bit_counter - 1;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
                WRITE_BLOCK_WAITE: begin
                    if(sclk_sig == 1) begin
                        if(i_data == 1) begin
                            state <= IDLE;
                            cmd_mode <= 1;
                        end
                    end
                    sclk_sig = ~sclk_sig;
                end
            endcase
        end
    end
endmodule
