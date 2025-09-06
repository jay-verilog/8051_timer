module timer_tb();
reg                               clk;
reg                               rst_n;
reg                               t0_in;
reg                               t1_in;
reg                               slave_wr;
reg                               slave_sel;
reg                               ext_trig;
reg      [SP_REGISTER_WIDTH-1:0]  slave_wdata;
reg      [SP_REGISTER_WIDTH-1:0]  slave_addr;
wire                              slave_ack;
wire     [SP_REGISTER_WIDTH-1:0]  slave_rdata;

parameter SP_REGISTER_WIDTH = 8;

parameter TL0_ADDR = 'h8a;
parameter TL1_ADDR = 'h8b;
parameter TH0_ADDR = 'h8c;
parameter TH1_ADDR = 'h8d;
parameter TMOD     = 'h89;
parameter TCON     = 'h88;

timer dut (
.clk         (clk),
.rst_n       (rst_n),
.t0_in       (t0_in),
.t1_in       (t0_in),
.slave_wr    (slave_wr),
.slave_sel   (slave_sel),
.ext_trig    (ext_trig),
.slave_wdata (slave_wdata),
.slave_addr  (slave_addr),
.slave_ack   (slave_ack),
.slave_rdata (slave_rdata)
);

initial
begin
   clk = 0;
   forever 
   begin
#5    clk = ~clk;
   end
end

initial
begin
   t0_in = 0;
   forever 
   begin
#10    t0_in = ~t0_in;
   end
end

initial 
begin
    rst_n = 0;
#15 rst_n = 1;
end

initial
begin
   slave_wr    = 0;
   slave_sel   = 0;
   ext_trig    = 0;
   slave_addr  = 0; 
#25
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = 0;
#10
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TMOD;
#10
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TL0_ADDR;
#10
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TH0_ADDR;
#10
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TCON;
#10
   slave_wr    = 1;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = 0;
#10
   slave_wr    = 0;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TL0_ADDR;
#699900
   slave_wr    = 0;
   slave_sel   = 1;
   ext_trig    = 0;
   slave_addr  = TCON;



#100 $finish;
end

initial 
begin
   slave_wdata <= 0;
#25
   slave_wdata <= 'h11;
#10
   slave_wdata <= 'h56;
#10
   slave_wdata <= 'h12;
#10
   slave_wdata <= 'h50;

end

initial 
begin   
   $dumpfile("timer.vcd");
   $dumpvars(0,timer_tb);
end

endmodule
