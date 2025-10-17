`timescale 1ns/1ps

module tb_apb;

logic        tb_pclk;
logic        tb_prstn;
logic        tb_psel;
logic        tb_penable;
logic        tb_pwrite;
logic [31:0] tb_paddr;
logic [31:0] tb_pwdata;
logic [31:0] tb_prdata;
logic        tb_pready;
logic        tb_pslverr;

apb_ram apbram0(
    .pclk    (tb_pclk),
    .prstn   (tb_prstn),
    .psel    (tb_psel),
    .penable (tb_penable),
    .pwrite  (tb_pwrite),
    .paddr   (tb_paddr),
    .pwdata  (tb_pwdata),
    .prdata  (tb_prdata),
    .pready  (tb_pready),
    .pslverr (tb_pslverr)

);

initial begin
    tb_pclk = 1'b0;
    tb_prstn = 1'b0;
end
always begin
    #5 tb_pclk = ~ tb_pclk;
end

task send_data(input [31:0] addr, input [31:0] data);
    @(posedge tb_pclk)
    tb_psel <= 1'b1;
    tb_pwrite <= 1'b1;
    tb_paddr <= addr;
    tb_pwdata <= data;
    @(posedge tb_pclk)
    tb_penable <= 1'b1;
    @(posedge tb_pclk)
    tb_psel <= 1'b1;
    tb_penable <= 1'b0;
endtask



task rcv_data(input [31:0] addr, output [31:0] data);
    @(posedge tb_pclk)
    tb_psel <= 1'b1;
    tb_pwrite <= 1'b0;
    tb_paddr <= addr;
    @(posedge tb_pclk)
    tb_penable <= 1'b1;
    @(posedge tb_pclk)
    tb_psel <= 1'b0;
    tb_penable <= 1'b0;
    data <= tb_prdata;
endtask

initial begin
    
    for(int i = 0; i < 5; i++) begin
        @(posedge tb_pclk);
    end
    tb_prstn = 1'b1;
    
    for(int i = 0; i < 20; i++) begin
        send_data(i,i);
    end
    @(posedge tb_pclk);
    @(posedge tb_pclk);
    for(int i = 0; i < 20; i++) begin
        int data;
        rcv_data(i,data);
        $display("data = %d\n",data);
    end
    $finish();
end




endmodule