module spi(spi_if vif);
  
  typedef enum bit [1:0] {idle = 2'b00, enable = 2'b01, send = 2'b10, comp = 2'b11 } state_type;
  state_type state = idle;
  
  int countc = 0;
  int count = 0;
 
  /////////////////////////generation of sclkt
 always@(posedge vif.clk)
  begin
    if(vif.rst == 1'b1) begin
      countc <= 0;
      vif.sclk <= 1'b0;
    end
    else begin 
      if(countc < 10 )   /// fclk / 20
          countc <= countc + 1;
      else
          begin
          countc <= 0;
          vif.sclk <= ~vif.sclk;
          end
    end
  end
  
  //////////////////state machine
    reg [11:0] temp;
    
  always@(posedge vif.sclk)
  begin
    if(vif.rst == 1'b1) begin
      vif.cs <= 1'b1; 
      vif.mosi <= 1'b0;
    end
    else begin
     case(state)
         idle:
             begin
               if(vif.newd == 1'b1) begin
                 state <= send;
                 temp <= vif.din; 
                 vif.cs <= 1'b0;
               end
               else begin
                 state <= idle;
                 temp <= 8'h00;
               end
             end
       
       
       send : begin
         if(count <= 11) begin
           vif.mosi <= temp[count]; /////sending lsb first
           count <= count + 1;
         end
         else
             begin
               count <= 0;
               state <= idle;
               vif.cs <= 1'b1;
               vif.mosi <= 1'b0;
             end
       end
       
                
      default : state <= idle; 
       
   endcase
  end 
 end
  
endmodule
///////////////////////////
 
interface spi_if;
 
  
  logic clk;
  logic newd;
  logic rst;
  logic [11:0] din;
  logic sclk;
  logic cs;
  logic mosi;

  modport drv_vif (input clk, cs, sclk, mosi, output newd, rst, din);
  modport mon_vif (input clk, cs, sclk, mosi, newd);
  modport dut_vif (input clk, newd, rst, din, output sclk, cs, mosi);
endinterface