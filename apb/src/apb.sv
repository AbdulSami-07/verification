`timescale 1ns / 1ps

module apb_ram
(
    input pclk,
    input prstn,
    input psel,
    input penable,
    input pwrite,
    input [31:0] paddr,
    input [31:0] pwdata,
    output [31:0] prdata,
    output pready,
    output pslverr

);

typedef enum {idle = 0, setup = 1, access = 2} state;

state p_state = idle;

wire clk, rst;
assign clk = pclk;
assign rstn = prstn;

reg [31:0] mem [31:0];
reg busy_t = 1'b0;
reg wr_en_t = 1'b0;
reg [31:0] addr_t = 'd0;
reg [31:0] rdata_t = 'd0;
reg [31:0] wdata_t = 'd0;

always @(posedge clk, negedge rstn) begin
    if (rstn == 1'b0) begin
        rdata_t <= 'd0;
    end 
    else begin
        if (wr_en_t == 1'b1) begin
            mem[addr_t] <= wdata_t;
        end
        else begin
            rdata_t <= mem[addr_t];
        end
    end
end

reg pready_t = 1'b0 , pslverr_t = 1'b0, psel_t = 1'b0, pwrite_t = 1'b0, penable_t = 1'b0;
reg [31:0] prdata_t = 'd0, paddr_t = 'd0, pwdata_t = 'd0;

always @(posedge clk, negedge rstn)
begin
    if (rstn == 1'b0) begin
        wr_en_t <= 1'b0;
        wdata_t <= 'd0;
        addr_t <= 'd0;
        pready_t <= 1'b1;
        pslverr_t <= 1'b0;
        prdata_t <= 'd0;
        p_state <= idle;
        penable_t <= 1'b0;
        pwrite_t <= 1'b0;
        psel_t <= 1'b0;
        paddr_t <= 'd0;
        pwdata_t <= 'd0;
        prdata_t <= 'd0;
        
    end
    case(p_state)
        idle:
        begin
           wr_en_t <= 1'b0;
           wdata_t <= 'd0;
           rdata_t <= 'd0;
           pready_t <= 1'b1;
           pslverr_t <= 1'b0;
           prdata_t <= 'd0;
           p_state <= idle;
           penable_t <= 1'b0;
           pwrite_t <= 1'b0;
           psel_t <= 1'b0;
           paddr_t <= 'd0;
           pwdata_t <= 'd0;
           prdata_t <= 'd0;
           if (psel == 1'b1) begin
               psel_t <= psel;
               pwrite_t <= pwrite;
               pwdata_t <= pwdata;
               paddr_t <= paddr;
               p_state <= setup;
           end
        end
        
        setup:
        begin
            wr_en_t <= pwrite_t;
            p_state <= setup;
            penable_t <= penable;
            pready_t <= ~busy_t;
            pslverr_t <= 1'b0;
            if (penable == 1'b1) begin
                addr_t <= paddr;
                wdata_t <= pwdata;
                p_state <= access;
            end
        end
        
        access:
        begin
            pready_t <= ~busy_t;
            pslverr_t <= 1'b0;
            if(~pwrite_t)
                prdata_t <= rdata_t;
            else
                prdata_t <= 'd0;
            
            if (~busy_t) begin
                if (psel == psel_t) begin
                    p_state <= setup;
                end
                else begin
                    p_state <= idle;
                end
            end
            else begin
               p_state <= idle;
               wr_en_t <= 1'b0;
               wdata_t <= 'd0;
               rdata_t <= 'd0;
               pready_t <= 1'b1;
               pslverr_t <= 1'b1;
               prdata_t <= 'd0;
               penable_t <= 1'b0;
               pwrite_t <= 1'b0;
               psel_t <= 1'b0;
               paddr_t <= 'd0;
               pwdata_t <= 'd0;
               prdata_t <= 'd0;
            end
                
        end
        
        
        default:
        begin
            wr_en_t <= 1'b0;
            wdata_t <= 'd0;
            rdata_t <= 'd0;
            pready_t <= 1'b1;
            pslverr_t <= 1'b1;
            prdata_t <= 'd0;
            p_state <= idle;
            penable_t <= 1'b0;
            pwrite_t <= 1'b0;
            psel_t <= 1'b0;
            paddr_t <= 'd0;
            pwdata_t <= 'd0;
            prdata_t <= 'd0;
        end
    endcase
end

assign prdata = prdata_t;
assign pready = pready_t;
assign pslverr = pslverr_t;

endmodule

