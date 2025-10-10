`timescale 1ns / 1ps
module fifo(ff_if vif);
  
  // Pointers for write and read operations
  reg [3:0] wptr = 0, rptr = 0;
  
  // Counter for tracking the number of elements in the FIFO
  reg [4:0] cnt = 0;
  
  // Memory array to store data
  reg [7:0] mem [15:0];
  integer i = 0;
  always @(posedge vif.clk)
    begin
      if (vif.rst == 1'b1)
        begin
          // Reset the pointers and counter when the reset signal is asserted
          wptr <= 0;
          rptr <= 0;
          cnt  <= 0;
          for ( i = 0; i < 16; i = i + 1) begin
              mem[i] <= 0;
          end
        end
      else if (vif.wr && !vif.full)
        begin
          // Write data to the FIFO if it's not full
          mem[wptr] <= vif.din;
          wptr      <= wptr + 1;
          cnt       <= cnt + 1;
        end
      else if (vif.rd && !vif.empty)
        begin
          // Read data from the FIFO if it's not empty
          vif.dout <= mem[rptr];
          rptr <= rptr + 1;
          cnt  <= cnt - 1;
        end
    end
 
  // Determine if the FIFO is empty or full
  assign vif.empty = (cnt == 0) ? 1'b1 : 1'b0;
  assign vif.full  = (cnt == 16) ? 1'b1 : 1'b0;
 
endmodule
