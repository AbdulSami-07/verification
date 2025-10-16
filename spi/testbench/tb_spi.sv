`timescale 1ns / 1ps
class transaction;
    bit newd;
    rand bit [11:0] din;
    bit cs;
    bit mosi;

    constraint din_newd_c {
        din dist {
            [0:20]:= 20, [21:100]:= 20, [101:256]:= 60
        };
    }

    function transaction copy();
        copy = new();
        copy.newd = this.newd;
        copy.din = this.din;
        copy.mosi = this.mosi;
        copy.cs = this.cs;
    endfunction;

    function void display(input string str);
        $display("[%0s]: newd : %0d, din : %0d, cs : %0d, mosi: %0d", str, this.newd, this.din, this.cs, this.mosi);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    mailbox #(transaction) mbxref;
    int count;
    int i = 0;
    event done;
    event sconext;
    event drvnext;

    function new(input int count, mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        tr = new();
        this.mbx = mbx;
        this.mbxref = mbxref;
        this.count = count;
    endfunction

    task run();
        repeat(count) begin
            assert(tr.randomize()) else $display("Randomization failed");
            tr.newd = 1;
            mbx.put(tr.copy());
            mbxref.put(tr.copy());
            $display("----------------- Start of %0d Test -----------------",i++);
            tr.display("GEN");
//            @(drvnext);
            @(sconext);
        end
        ->done;
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual spi_if vif;
    event drvnext;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        @(posedge vif.clk)
            vif.rst <= 1'b1;
        repeat(5) @(posedge vif.clk);
        @(posedge vif.clk)
            vif.rst <= 1'b0;
    endtask

    task write();
        @(posedge vif.sclk);
        vif.newd <= tr.newd;
        vif.din  <=  tr.din;
        @(posedge vif.sclk);
        $display("[DRV]: newd : %0d, din : %0d, cs : %0d,", this.tr.newd, this.tr.din, vif.cs);
        vif.newd <= 0;
        vif.din <= 0;
        @(posedge vif.cs);
    endtask

    task run();
        forever begin
            this.mbx.get(tr);
            write();
            ->drvnext;
        end
    endtask

endclass

class monitor;
    transaction tr;
    mailbox #(bit [11:0]) datambx;
    bit [11:0] dout;
    virtual spi_if vif;
    

    function new(mailbox #(bit [11:0]) datambx);
        this.tr = new();
        this.datambx = datambx;
    endfunction

    task read();
        int i = 0;
        repeat(1) @(posedge vif.sclk);
        while(vif.cs == 1'b0) begin
            @(posedge vif.sclk);
            if (vif.cs == 1'b0) begin
                this.dout[i] = vif.mosi;
                $display("[MON]: newd : %0d, cs : %0d, i : %0d, mosi : %0d", vif.newd, vif.cs , i, vif.mosi);
                i = i + 1;
                if (i == 12)
                    datambx.put(dout);
            end
        end
    endtask;

    task run();
        forever begin
            read();
            
        end
    endtask
endclass

class scoreboard;
    bit [11:0] dout;
    transaction reftr;
    mailbox #(bit [11:0]) datambx;
    mailbox #(transaction) refmbx;
    event sconext;
    event drvnext;

    function new(mailbox #(bit [11:0]) datambx, mailbox #(transaction) refmbx);
        this.reftr = new();
        this.datambx = datambx;
        this.refmbx = refmbx;
    endfunction

    task run();
        forever begin
            @(drvnext);
            refmbx.get(reftr);
            datambx.get(dout);
            if (reftr.din == dout) begin
                $display("Success!");
                $display("----------------------------------------------------");
            end
            else begin
                $display("Failure!");
                $display("Data from MON : %0d, Data from GEN : %0d", dout,reftr.din);
                $display("----------------------------------------------------");
            end
            ->sconext;   
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    mailbox #(transaction) mbx;
    mailbox #(transaction) refmbx;
    mailbox #(bit [11:0]) datambx;
    
    virtual spi_if vif;

    event drvnext;
    event sconext;
    event done;

    function new(input int count, virtual spi_if vif);
        this.vif = vif;
        this.mbx = new();
        this.refmbx = new();
        this.datambx = new();
        gen = new(count, this.mbx, this.refmbx);
        drv = new(this.mbx);
        mon = new(this.datambx);
        sco = new(this.datambx, this.refmbx);
        gen.drvnext = drvnext;
        gen.sconext = sconext;
        gen.done = done;
        drv.drvnext = drvnext;
        sco.sconext = sconext;
        sco.drvnext = drvnext;
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

module tb_spi();
    spi_if vif();
    
    spi dut(vif.dut_vif);
    
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

