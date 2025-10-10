`timescale 1ns / 1ps

interface ff_if;
    logic clk;
    logic rst;
    logic wr;
    logic rd;
    logic [7:0] din;
    logic [7:0] dout;
    logic empty;
    logic full;
    
    modport drv_vif (input clk, empty, full, dout, output rst, wr, rd, din);
    modport mon_vif (input clk, empty, full, din, dout,output wr, rd);
    modport dut_vif (input clk, rst, wr, rd, din, output dout, empty, full);
endinterface

class transaction;
    rand bit oper;
    bit wr;
    bit rd;
    rand bit [7:0] din; 
    bit [7:0] dout;
    bit empty;
    bit full;
    
    constraint oper_c {
        oper dist {1:/ 50, 0:/50};
    }
    
    function transaction copy();
        copy = new();
        copy.oper = this.oper;
        copy.wr = this.wr;
        copy.rd = this.rd;
        copy.din = this.din;
        copy.dout = this.dout;
        copy.empty = this.empty;
        copy.full = this.full;
    endfunction
    
    function void display (input string str);
        $display("[%0s]: wr : %0d, rd : %0d, din : %0d, dout : %0d, empty : %0d, full : %0d",str,this.wr, this.rd, this.din, this.dout, this.empty, this.full);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    event done;
    event sconext;
    int count;
    
    function new(mailbox #(transaction) mbx, input int count);
        this.mbx = mbx;
        this.count = count;
        this.tr = new();
    endfunction
    
    task run();
        repeat(this.count) begin
            assert(this.tr.randomize()) else $display("[GEN]: randomization failed");
            if (this.tr.oper) begin
                this.tr.wr = 1'b1;
                this.tr.rd = 1'b0;
            end
            else begin
                this.tr.rd = 1'b1;
                this.tr.wr = 1'b0;
            end
            mbx.put(this.tr.copy());
            tr.display("GEN");
            @(sconext);
        end
        -> done;
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual ff_if vif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        this.tr = new();
    endfunction
    
    task reset();
        vif.rst = 1'b1;
        vif.wr = 1'b0;
        vif.rd = 1'b0;
        repeat(5) @(posedge vif.clk);
        vif.rst = 1'b0;
    endtask
    
//    task post_test();
//        repeat(3) @(posedge vif.clk);
//    endtask

    task write();
        @(posedge vif.clk);
        vif.wr <= 1'b1;
        vif.rd <= 1'b0;
        vif.din <= tr.din;
        @(posedge vif.clk);   
        vif.wr <= 1'b0;
        $display("[DRV]: wr : %0d, rd : %0d, din : %0d, dout : %0d, empty : %0d, full : %0d",vif.wr, vif.rd, vif.din, tr.dout, vif.empty, vif.full);
        @(posedge vif.clk);
    endtask
    
    task read();
        @(posedge vif.clk);
        vif.wr <= 1'b0;
        vif.rd <= 1'b1;
        vif.din <= tr.din;
        @(posedge vif.clk);
        vif.rd <= 1'b0;
        $display("[DRV]: wr : %0d, rd : %0d, din : %0d, dout : %0d, empty : %0d, full : %0d",vif.wr, vif.rd, tr.din, tr.dout, vif.empty, vif.full);
        @(posedge vif.clk);
    endtask
    
    task run();
        forever begin
            mbx.get(tr);
            if (tr.oper == 1'b1)
                write();
            else
                read();    
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mbx;
    
    virtual ff_if vif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        this.tr = new();
    endfunction
    
    task run();  
        forever begin
            repeat(2) @(posedge vif.clk);
            tr.wr = vif.wr;
            tr.rd = vif.rd;
            tr.din = vif.din;
            tr.empty = vif.empty;
            tr.full = vif.full;
            
            @(posedge vif.clk);
            tr.dout = vif.dout;
            mbx.put(tr);
            tr.display("MON");       
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mbx;
    event sconext;
    
    bit [7:0] queue[$];
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction
    
    task run();
          forever begin
              mbx.get(tr);
              if (tr.wr && !tr.full) begin
                  queue.push_front(tr.din);
                  tr.display("SCO");
                  $display("data is written to fifo");
              end
              else if (tr.wr && tr.full) begin
                  tr.display("SCO");
                  $display("fifo is full");
              end
              else if (tr.rd && !tr.empty) begin
                  if (queue.pop_back() == tr.dout) begin
                    tr.display("SCO");
                    $display("success");
                  end
                  else begin
                    tr.display("SCO");
                    $display("failure");
                  end
              end
              else begin
                  tr.display("SCO");
                  $display("fifo is empty");
              end
              $display("--------------------------------------------------");
              ->sconext;
          end  
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    mailbox #(transaction) gdmbx;
    mailbox #(transaction) msmbx;

    virtual ff_if vif;
    event done;
    event sconext;
    
    function new(input int count, virtual ff_if vif);
        gdmbx = new();
        msmbx = new();
        gen = new(this.gdmbx,count);
        drv = new(this.gdmbx);
        mon = new(this.msmbx);
        sco = new(this.msmbx);
        this.vif = vif;
        gen.sconext = sconext;
        sco.sconext = sconext;
        gen.done = done;
        
        drv.vif = this.vif.drv_vif;
        mon.vif = this.vif.mon_vif;
    endfunction
    
    task pre_test();
        drv.reset();
    endtask;
    
    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_none
    endtask
    
    task post_test();
        @(done);
        $finish();
    endtask
    
    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass

module tb_fifo();
    ff_if vif();
    
    fifo dut(vif.dut_vif);
    
    environment env;
    
    initial begin
        vif.clk = 1'b0;
    end
    
    always #5 vif.clk = ~vif.clk;

    initial begin
        env = new(20,vif);
        env.run();
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule