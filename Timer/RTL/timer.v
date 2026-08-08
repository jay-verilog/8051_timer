`include "sfr_def_addr.v"
`include "sfr_def_bit_addr.v"

module timer_controller
(
input                               timer_controller_clk,
input                               timer_controller_rst_n,

input                               timer_controller_t0_in,
input                               timer_controller_t1_in,

input                               timer_controller_wr_en,
input                               timer_controller_rd_en,

input                               timer_controller_sel_intrnl_reg,

input                               timer_controller_ext_t0,
input                               timer_controller_ext_t1,

input                               timer_controller_int0,
input                               timer_controller_int1,

input                               timer_controller_bit_nbyte_addr,

input      [ADDR_WIDTH-1:0]         timer_controller_addr,
input      [$clog2(DATA_WIDTH)-1:0] timer_controller_bit_addr,

input      [DATA_WIDTH-1:0]         timer_controller_wdata,
output reg [DATA_WIDTH-1:0]         timer_controller_rdata,

output reg                          timer_controller_t0_flag,
output reg                          timer_controller_t1_flag
);
parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 8;

parameter REGISTER_WIDTH = 8;
parameter SP_REGISTER_DEPTH = 256;
parameter TCON_WIDTH_TIMER = 4;
parameter FREQ_DIVIDE_12 = 12;

reg [$clog2(FREQ_DIVIDE_12):0] divide_12_freq;
reg divide_12_clk;



// Timer Mode Register
reg [REGISTER_WIDTH-1:0] tmod;
// Timer Control Register
reg [(REGISTER_WIDTH/2)-1:0] tcon;

// timer 0
reg [REGISTER_WIDTH-1:0] tl0;  // lower  8 bit.
reg [REGISTER_WIDTH-1:0] th0;  // higher 8 bit.
// timer 1
reg [REGISTER_WIDTH-1:0] tl1;  // lower  8 bit.
reg [REGISTER_WIDTH-1:0] th1;  // higher 8 bit.

// THESE Registers for,To detect negaedge ext_int 
reg sample_ext_countr_t0;
reg sample_ext_countr_t1;

reg sample_ext_countr_t0_shift;
reg sample_ext_countr_t1_shift;

// START COUNTING
reg countr_t0_flag;
reg countr_t1_flag;

// timer overflow 
reg t0_overflag;   
reg t1_overflag;   
reg th0_overflow;  //  FOR MODE 3

// RUN FLAG (software gate, GATEx == 0)
reg software_ctrl_t0;
reg software_ctrl_t1;

// RUN FLAG (hardware gate, GATEx == 1)
reg hardware_gating_t0;
reg hardware_gating_t1;




// Frequency Divide By 12

always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      divide_12_freq <= {$clog2(FREQ_DIVIDE_12){1'b0}};
      divide_12_clk  <= 1'b0;
   end

   else 
   begin
      if(divide_12_freq == ((FREQ_DIVIDE_12 - 1'b1)))
      begin
         divide_12_clk  <= 1'b1;
         divide_12_freq <= {$clog2(FREQ_DIVIDE_12){1'b0}};
      end
  
      else 
      begin
         divide_12_clk  <=  1'b0;
         divide_12_freq <= divide_12_freq + 1'b1;
      end
   end
end


// ---------------------------------------------------------------TMOD---------------------------------------------------------------------------------------------TMOD ---------------------------------
// TMOD
// -------7------------6------------5--------4-----------3-------------2------------1----------0------
// |   T1 Gate   |   T1 C/T   |   T1M1  |   T1M0   |  T0 Gate   |   T0 C/T   |   T0 M1   |   T0 M0   |
// ---------------------------------------------------------------------------------------------------
// M1M0 = 00 -> Mode 0 (13-bit timer)   
// M1M0 = 01 -> Mode 1 (16-bit timer)
// M1M0 = 10 -> Mode 2 (8-bit auto-reload)  
// M1M0 = 11 -> Mode 3 (split 8-bit timers, T0 only)


// ---------------------------------------------------------------TCON---------------------------------------------------------------------------------------------TCON -------------------------------
// -------7------------6------------5--------4-----------3-------------2------------1----------0------
// |     TF1	 |     TR1   |	   TF0	 |  TR0	   |    IE1     |     IT1      |   IE0   |    IT0    |
// ---------------------------------------------------------------------------------------------------
// |------------------- USED ----------------------|--------------- UNUSED --------------------------|
//                                                 |-------------- INTERRUPT ------------------------|


// ---------------------------------------------------------------TMOD---------------------------------------------------------------------------------------------TMOD always block -------------------------------

always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      tmod <= {REGISTER_WIDTH{1'b0}};
   end
   else
   begin
      if(timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TMOD)
      begin
         tmod <= timer_controller_wdata;
      end
   end
end




always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
 if(timer_controller_rst_n == 1'b0)
   begin
      tcon  <= {(REGISTER_WIDTH/2){1'b0}};
   end
   else
   begin
      if(!timer_controller_bit_nbyte_addr && ((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TCON))
      begin
         tcon <= timer_controller_wdata[7:4];
      end

      else if(timer_controller_bit_nbyte_addr && ((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TCON) && (timer_controller_bit_addr > (TCON_WIDTH_TIMER-1)))
      begin
         tcon[timer_controller_bit_addr-TCON_WIDTH_TIMER] <= timer_controller_wdata[0];
      end

      else
      begin
         if(t0_overflag)
         begin
            tcon[`TF0-TCON_WIDTH_TIMER] <= 1'b1;
         end

         if((tmod[`T0M1] == 1'b1) && (tmod[`T0M0] == 1'b1))
         begin
            // Timer0 Mode 3 
            if(th0_overflow)
            begin
               tcon[`TF1-TCON_WIDTH_TIMER] <= 1'b1;
            end
         end
         else
         begin
            // Normal case 
            if(t1_overflag)
            begin
               tcon[`TF1-TCON_WIDTH_TIMER] <= 1'b1;
            end
         end
      end

   end
end



always @(*)
begin
   hardware_gating_t0 = tmod[`GATE0] & tcon[`TR0-TCON_WIDTH_TIMER] & timer_controller_int0;
   software_ctrl_t0   = (~tmod[`GATE0]) & tcon[`TR0-TCON_WIDTH_TIMER];
end


always @(*)
begin
   hardware_gating_t1 = tmod[`GATE1] & tcon[`TR1-TCON_WIDTH_TIMER] & timer_controller_int1;
   software_ctrl_t1   = (~tmod[`GATE1]) & tcon[`TR1-TCON_WIDTH_TIMER];
end


// ----------------------------------------------------  EXTERNAL EVENT COUNTER -------------------------------------------------------------

//  T0 EXTERNAL EVENT DETECT
//  NEGEDGE TRIGGER
always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      sample_ext_countr_t0 <= 1'b0;
   end

   else
   begin
      sample_ext_countr_t0 <= timer_controller_ext_t0;
   end

end

always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      sample_ext_countr_t0_shift <= 1'b0;
   end

   else
   begin
      sample_ext_countr_t0_shift <= sample_ext_countr_t0;
   end
end

always @(*)
begin
   countr_t0_flag = (~sample_ext_countr_t0) & sample_ext_countr_t0_shift;
end


// ----------------------------------------------------  EXTERNAL EVENT COUNTER -------------------------------------------------------------

//  T1 EXTERNAL EVENT DETECT
//  NEGEDGE DETECTS 
always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      sample_ext_countr_t1 <= 1'b0;
   end

   else
   begin
      sample_ext_countr_t1 <= timer_controller_ext_t1;
   end

end

always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      sample_ext_countr_t1_shift <= 1'b0;
   end

   else
   begin
      sample_ext_countr_t1_shift <= sample_ext_countr_t1;
   end
end

always @(*)
begin
   countr_t1_flag = (~sample_ext_countr_t1) & sample_ext_countr_t1_shift;
end

//----------------------------------------Timer 0 ------------------------------------------------------------------------------------------------------------------------------ Timer 0 BEGIN-----------------------


always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      tl0            <= 8'b0000_0000;
      th0            <= 8'b0000_0000;
      t0_overflag    <= 1'b0;
      th0_overflow   <= 1'b0;
   end

   else
   begin
      if((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TL0)
      begin
         tl0  <= timer_controller_wdata;
      end
      else if((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TH0)
      begin
         th0  <= timer_controller_wdata;
      end

// ----------------------------------------- MODE 0 : 13-bit timer/counter (T0M1=0, T0M0=0) -----------------------------------------------------------------------------------------
      else if(((tmod[`T0M1] == 1'b0) && (tmod[`T0M0] == 1'b0) && (hardware_gating_t0 || software_ctrl_t0) && (tmod[`CT0] ? countr_t0_flag : 1'b1)) && divide_12_clk)
      begin
         if({th0,tl0[4:0]} == 13'h1FFF)
         begin
            {th0,tl0[4:0]} <= 13'h0000;
            t0_overflag    <= 1'b1;
         end
         else
         begin
            {th0,tl0[4:0]} <= {th0,tl0[4:0]} + 1'b1;
            t0_overflag    <= 1'b0;
         end
      end

// -------------------------------------------- MODE 1 : 16-bit timer/counter (T0M1=0, T0M0=1) ------------------------------------------------------------------------------------------
      else if(((tmod[`T0M1] == 1'b0) && (tmod[`T0M0] == 1'b1) &&(hardware_gating_t0 || software_ctrl_t0) && (tmod[`CT0] ? countr_t0_flag : 1'b1)) && divide_12_clk)
      begin
         if({th0,tl0} == 16'hFFFF)
         begin
            {th0,tl0} <= 16'h0000;
            t0_overflag <= 1'b1;
         end
         else
         begin
            {th0,tl0} <= {th0,tl0} + 1'b1;
            t0_overflag <= 1'b0;
         end
      end

//----------------------------------- MODE 2 : 8-bit auto-reload (T0M1=1, T0M0=0) ---------------------------------------------------------------------------------------------------------
      else if(((tmod[`T0M1] == 1'b1) && (tmod[`T0M0] == 1'b0) && (hardware_gating_t0 || software_ctrl_t0) && (tmod[`CT0] ? countr_t0_flag : 1'b1)) && divide_12_clk)
      begin
         if(tl0 == 8'hFF)
         begin
            tl0         <= th0;
            t0_overflag <= 1'b1;
         end
         else
         begin
            tl0         <= tl0 + 1'b1;
            t0_overflag <= 1'b0;
         end
      end

//------------------------------------------- MODE 3 : split 8-bit timers (T0M1=1, T0M0=1) -------------------------------------------------------------------------------------------------------
      else if(((tmod[`T0M1] == 1'b1) && (tmod[`T0M0] == 1'b1))&& divide_12_clk)
      begin
         // ------------------------------------ Parallelly runs ---------------------------------------------------------------------------
         // TL0: independent 8-bit timer/counter T0
         if((hardware_gating_t0 | software_ctrl_t0) && (tmod[`CT0] ? countr_t0_flag : 1'b1))
         begin
            if(tl0 == 8'hFF)
            begin
               tl0         <= 8'h00;
               t0_overflag <= 1'b1;
            end
            else
            begin
               tl0         <= tl0 + 1'b1;
               t0_overflag <= 1'b0;
            end
         end
         else
         begin
            t0_overflag <= 1'b0;
         end
         // ------------------------------------ Parallelly runs ---------------------------------------------------------------------------
         // TH0: independent 8-bit TIMER only run by TR1
         if(tcon[`TR1-TCON_WIDTH_TIMER])
         begin
            if(th0 == 8'hFF)
            begin
               th0          <= 8'h00;
               th0_overflow <= 1'b1;
            end
            else
            begin
               th0          <= th0 + 1'b1;
               th0_overflow <= 1'b0;
            end
         end
         else
         begin
            th0_overflow <= 1'b0;
         end
      end

      else
      begin
         t0_overflag  <= 1'b0;
         th0_overflow <= 1'b0;
      end
   end
end


always @(posedge timer_controller_clk or negedge timer_controller_rst_n)
begin
   if(timer_controller_rst_n == 1'b0)
   begin
      tl1            <= 8'b0000_0000;
      th1            <= 8'b0000_0000;
      t1_overflag    <= 1'b0;
   end

   else
   begin
      if((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TL1)
      begin
         tl1  <= timer_controller_wdata;
      end

      else if((timer_controller_wr_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1) && timer_controller_addr == `TH1)
      begin
         th1  <= timer_controller_wdata;
      end

//-------------------------------- MODE 0 : 13-bit timer/counter (T1M1=0, T1M0=0) -------------------------------------------------------------------
      else if(((tmod[`T1M1] == 1'b0) && (tmod[`T1M0] == 1'b0) && (hardware_gating_t1 || software_ctrl_t1) && (tmod[`CT1] ? countr_t1_flag : 1'b1)) && divide_12_clk)
      begin
         if({th1,tl1[4:0]} == 13'h1FFF)
         begin
            {th1,tl1[4:0]} <= 13'h0000;
            t1_overflag    <= 1'b1;
         end
         else
         begin
            {th1,tl1[4:0]} <= {th1,tl1[4:0]} + 1'b1;
            t1_overflag    <= 1'b0;
         end
      end

//------------------------------- MODE 1 : 16-bit timer/counter (T1M1=0, T1M0=1) ----------------------------------------------------------------------
      else if(((tmod[`T1M1] == 1'b0) && (tmod[`T1M0] == 1'b1) && (hardware_gating_t1 || software_ctrl_t1) && (tmod[`CT1] ? countr_t1_flag : 1'b1))&& divide_12_clk)
      begin
         if({th1,tl1} == 16'hFFFF)
         begin
            {th1,tl1} <= 16'h0000;
            t1_overflag <= 1'b1;
         end
         else
         begin
            {th1,tl1} <= {th1,tl1} + 1'b1;
            t1_overflag <= 1'b0;
         end
      end

// ------------------------------- MODE 2 : 8-bit auto-reload (T1M1=1, T1M0=0) ---------------------------------------------------------------------
      else if(((tmod[`T1M1] == 1'b1) && (tmod[`T1M0] == 1'b0) && (hardware_gating_t1 || software_ctrl_t1) && (tmod[`CT1] ? countr_t1_flag : 1'b1)) && divide_12_clk)
      begin
         if(tl1 == 8'hFF)
         begin
            tl1         <= th1;
            t1_overflag <= 1'b1;
         end
         else
         begin
            tl1         <= tl1 + 1'b1;
            t1_overflag <= 1'b0;
         end
      end

      else
      begin
         t1_overflag <= 1'b0;
      end
   end
end



// ----------------------------------- REGISTER READ -----------------------------------------------------------------------------------------------------------------------------------REGISTER READ --------------------
always @(*)
begin

   if(timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TMOD)                        // READ TMOD
   begin
      timer_controller_rdata = tmod;
   end

   else if(!timer_controller_bit_nbyte_addr && (timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TCON))                 // READ TCON
   begin
      timer_controller_rdata = {tcon,4'b0000};
   end

   else if(timer_controller_bit_nbyte_addr && (timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TCON)&& (timer_controller_bit_addr > (TCON_WIDTH_TIMER-1)))   // READ TCON
   begin
      timer_controller_rdata  = {7'b000_0000,tcon[timer_controller_bit_addr-TCON_WIDTH_TIMER]};
   end

   else if(timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TL0)                   // READ TL0
   begin
      timer_controller_rdata = tl0;
   end

   else if(timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TH0)                   // READ TH0
   begin
      timer_controller_rdata = th0;
   end

   else if(timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TL1)                   // READ TL1
   begin
      timer_controller_rdata = tl1;
   end

   else if(timer_controller_rd_en == 1'b1 && timer_controller_sel_intrnl_reg == 1'b1 && timer_controller_addr == `TH1)                  // READ TH1
   begin
      timer_controller_rdata = th1;
   end

   else
   begin
      timer_controller_rdata = {REGISTER_WIDTH{1'b0}};
   end
end


always @(*)
begin
   timer_controller_t0_flag = tcon[`TF0-TCON_WIDTH_TIMER];
   timer_controller_t1_flag = tcon[`TF1-TCON_WIDTH_TIMER];
end

endmodule
