`timescale 1ns / 1ps

interface dff_if;
  logic clk;   // Clock signal
  logic rst;   // Reset signal
  logic din;   // Data input
  logic dout;  // Data output
  
  modport drv_vif (input clk, output rst, din);
  
  modport dut_vif (input clk, rst, din, output dout);
  
  modport mon_vif (input clk, dout);
endinterface

class transaction;
    randc bit din;
    bit dout;
    
    function transaction copy();
        copy = new();
        copy.din = this.din;
        copy.dout = this.dout;
    endfunction

    function display (input string str);
        $display("[%0s] : DIN : %0b, DOUT : %0b",str,this.din, this.dout);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    mailbox #(transaction) mbxref;
    event done;
    event sconext;
    int count;
    
    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        this.mbx = mbx;
        this.mbxref = mbxref;
        tr = new();
    endfunction
    
    task run();
        repeat(count) begin
            assert(tr.randomize()) else $display("[GEN] : Randomization Failed");
            mbx.put(tr.copy());
            mbxref.put(tr.copy());
            tr.display("GEN");
            @(sconext);
        end
        -> done;
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual dff_if vif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 1'b0;
        @(posedge vif.clk);
    endtask
    
    task run();
        forever begin
            mbx.get(tr);
            vif.din <= tr.din;
            @(posedge vif.clk);
            tr.display("DRV");
            vif.din <= 1'b0;
            @(posedge vif.clk);
        end
    endtask
    
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual dff_if vif;
    
    function new (mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction
    
    task run();
        tr = new();
        forever begin
            repeat(2) @(posedge vif.clk);
            tr.dout = vif.dout;
            mbx.put(tr);
            tr.display("MON");
            
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    transaction trref;
    mailbox #(transaction) mbx;
    mailbox #(transaction) mbxref;
    event sconext;
    
    function new (mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        this.mbx = mbx;
        this.mbxref = mbxref;
    endfunction

    task run();
        forever begin
            mbx.get(tr);
            mbxref.get(trref);
            tr.display("SCO");
            trref.display("REF");
            if (tr.dout == trref.din)
                $display("[SCO] : Data Matches");
            else
                $display("[SCO] : Data Mismatches");
            $display("----------------------------------------------------");
            ->sconext;

        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    event sconext;
    event done;
    
    mailbox #(transaction) gdmbx;
    mailbox #(transaction) gsmbx;
    mailbox #(transaction) msmbx;

    virtual dff_if vif;
    
    function new (virtual dff_if vif);
        this.gdmbx = new();
        this.gsmbx = new();
        this.msmbx = new();
        this.vif = vif;
        gen = new(gdmbx, gsmbx);
        drv = new(gdmbx);
        mon = new(msmbx);
        sco = new(msmbx, gsmbx);
        
        drv.vif = this.vif.drv_vif;
        mon.vif = this.vif.mon_vif;
        gen.sconext = sconext;
        sco.sconext = sconext;
        gen.done = done;
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
        join_any
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

module tb_dff;
    dff_if vif();
    
    dff dut(vif.dut_vif);
    
    environment env;
    
    initial begin
        vif.clk = 1'b0;
    end
    
    always #10 vif.clk = ~vif.clk;

    initial begin
        env = new(vif);
        env.gen.count = 20;
        env.run();
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule











