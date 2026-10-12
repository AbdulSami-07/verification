`timescale 1ns / 1ps

interface uart_if;
  logic clk;
  logic uclktx;
  logic uclkrx;
  logic rst;
  logic rx;
  logic [7:0] dintx;
  logic newd;
  logic tx;
  logic [7:0] doutrx;
  logic donetx;
  logic donerx;
  
endinterface

class transaction();
    typedef enum bit {write = 1'b0, read = 1'b1} oper_type;
    randc oper_type op;
    bit rx;
    bit [7:0] dintx;
    bit newd;
    bit tx;
     
endclass

module tb_uart();

endmodule
