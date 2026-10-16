// SPDX-FileCopyrightText: 2022 CHILI.CHIPS.LLC
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// LOAD and STORE instructions
//==========================================================================

module edubos5
  import edubos5_pkg::*;
#(
    parameter int EN_WAIT4REGS   = 0,     // 0 for 2-stage CPU pipeline
    parameter bit GOWIN_FAST_OP  = 1'b0,
    parameter bit TARGET_IS_ASIC = 1'b0   // 1: x0 forced to 0 by a read mux, not RAM init
) (
    input logic clk,
    input logic arst_n, // reset button

    //Intruction Memory access
    output cpu_pc_t   imem_addr,
    input  cpu_data_t imem_rdat,
    input  logic      imem_rdy,   // IMEM answers in one cycle: not used
    output logic      imem_vld,


    //Data Memory access
    output cpu_addr_t dmem_addr,
    output we_bs_t    dmem_we,
    output logic      dmem_strobe,
    output cpu_data_t dmem_wdat,
    input  cpu_data_t dmem_rdat,

    input  logic dmem_rdy,
    output logic dmem_vld

);

  cpu_data_t rs1, rf_wdat;
  cpu_data_t rs2;
  logic      rf_we;  // write enable for the register file

  cpu_pc_t   pc;
  cpu_pc_t inc_pc, next_pc, pc_imm, pc_auipc;

  // STOREs are always expected to execute, no waiting on dmem_rdy
  typedef enum logic [2:0] {
    FETCH_INSTR = 3'd0,
    WAIT4REGS   = 3'd1,
    LOAD_DATA   = 3'd2,
    WAIT_DATA   = 3'd3,
    EXECUTE     = 3'd4
  } state_t;

  state_t       state;

  // ALU input and outputs
  logic   [4:0] shamt;  // SHift AMounT from immediate or rs2
  cpu_data_t aluin_1, aluin_2, alu_out;  // 32-bit IO from the ALU

  logic eq, lt, ltu;

  cpu_data_t           dmem_rdat_reg;
  logic                dmem_rdy_reg;

  // no-connects: IMEM ready, the low bits of the word-aligned immediates and
  // the decode bits nothing reads after the decode cycle
  logic                NC_imem_rdy;
  logic          [5:0] NC_imm_low;
  logic          [1:0] NC_decode_reg;

  //-------------------------------------------------
  // instruction decoder
  //-------------------------------------------------
  instr_t              instr;
  instr_decode_t       instr_decode;

  always_comb begin : _instr_decode

    instr_decode = '0;

    case (instr.opcode)
      ALUREG:  instr_decode.ALUREG = HI;
      ALUIMM:  instr_decode.ALUIMM = HI;
      BRNCH:   instr_decode.BRNCH = HI;
      JALR:    instr_decode.JALR = HI;
      JAL:     instr_decode.JAL = HI;
      AUIPC:   instr_decode.AUIPC = HI;
      LUI:     instr_decode.LUI = HI;
      LOAD:    instr_decode.LOAD = HI;
      STORE:   instr_decode.STORE = HI;
      FENCE:   instr_decode.FENCE = HI;
      SYSTEM:  instr_decode.SYSTEM = HI;
      default: instr_decode.SYSTEM = HI;
    endcase
  end : _instr_decode

  instr_decode_t instr_decode_reg;
  assign NC_imem_rdy   = imem_rdy;
  assign NC_decode_reg = {instr_decode_reg.FENCE, instr_decode_reg.SYSTEM};
  always_ff @(posedge clk) begin : _instr_decode_flop
    instr_decode_reg <= instr_decode;
  end : _instr_decode_flop
  //-------------------------------------------------
  // assembly of immediates
  //-------------------------------------------------
  cpu_data_t imm_iload, imm_uload, imm_store, imm_brnch, imm_jump;

  always_comb begin : _immediates
    imm_iload = {
      {20{instr.grp.imm.imm11_0[11]}},  //[31:12] upper part is sign-expanded
      instr.grp.imm.imm11_0
    };  //[11:0]  LOWER part is from instruction

    imm_uload = {
      instr.grp.uimm.imm31_12,  //[31:12] UPPER part is from instruction
      12'd0
    };  //[11:0]  lower part is dummy

    imm_store = {
      {20{instr.grp.store.imm11_5[11]}},  //[31:12] upper part is sign-expanded
      instr.grp.store.imm11_5
      ,  //-\
      instr.grp.store.imm4_0
    };  //-/ [11:0]

    imm_brnch = {
      {20{instr.grp.brnch.imm12}},  //[31:12] sign-expanded
      instr.grp.brnch.imm11
      ,  //-\
      instr.grp.brnch.imm10_5,  // | [11:1]
      instr.grp.brnch.imm4_1,  //-/
      1'b0
    };  //[0]

    imm_jump = {
      {12{instr.grp.jump.imm20}},  //[31:20] sign-expanded
      instr.grp.jump.imm19_12
      ,  //-\
      instr.grp.jump.imm11,  // | [19:1]
      instr.grp.jump.imm10_1,  //-/
      1'b0
    };  //[0]
  end : _immediates

  // flopping the immediates, solving timing by being inputs to combo strucutres
  funct3_brnch_t funct3_brnch;
  funct3_load_t  funct3_imm;
  logic          funct7_alu;

  cpu_data_t     imm_uload_reg;
  cpu_pc_t       pc_imm_reg;

  assign NC_imm_low = {imm_brnch[1:0], imm_jump[1:0], imm_uload_reg[1:0]};

  always_ff @(posedge clk) begin
    funct3_brnch  <= instr.grp.brnch.func3;
    funct7_alu    <= instr.grp.reg2reg.func7[5];
    funct3_imm    <= instr.grp.imm.func3;

    pc_imm_reg    <= pc_imm;
    imm_uload_reg <= imm_uload;
  end

  //-----------------------------------------------------------------
  // 2 RF read ports for reg fetch, address out, data and instr fetch
  //-----------------------------------------------------------------
  //drive instr address
  always_comb begin : _fetch_regs_instr
    if (state == FETCH_INSTR) begin
      imem_addr = next_pc[31:2];
    end
    else begin
      imem_addr = pc;
    end
    instr = imem_rdat;
  end : _fetch_regs_instr

  //------------------------------------------
  // RF writeback, reset in a software handler
  //------------------------------------------
  edubos5_rf #(
      .TARGET_IS_ASIC(TARGET_IS_ASIC)
  ) u_rf (
      .clk     (clk),                    //i
      .rs1_addr(instr.grp.reg2reg.rs1),  //i
      .rs2_addr(instr.grp.reg2reg.rs2),  //i
      .rd_addr (instr.grp.reg2reg.rd),   //i
      .rf_we   (rf_we),                  //i

      .rf_wdat(rf_wdat),  //o
      .rs1    (rs1),      //o
      .rs2    (rs2)       //o
  );

  //----------------------------
  // Load/Store signals and data
  //----------------------------

  cpu_addr_t ls_offset;
  cpu_data_t load_to_reg, dmem_wdat_next, dmem_addr_next;
  we_bs_t dmem_we_next;

  cpu_data_t rs1_reg, rs2_reg;
  cpu_data_t ls_offset_reg;

  always_ff @(posedge clk) begin
    rs1_reg       <= rs1;
    rs2_reg       <= rs2;
    ls_offset_reg <= ls_offset;
  end

  always_comb begin : _load_store

    //setting up the address to read/write
    ls_offset      = instr_decode.LOAD ? cpu_addr_t'(imm_iload) : cpu_addr_t'(imm_store);

    //strobe the memory
    dmem_strobe    = instr_decode_reg.LOAD | instr_decode_reg.STORE;

    //drive the write-enable signal
    dmem_we_next   = NOWR;
    dmem_wdat_next = rs2_reg;
    dmem_addr_next = cpu_addr_t'(ls_offset_reg + cpu_addr_t'(rs1_reg));
    //differentiating between STORE instructions
    if (instr_decode_reg.STORE) begin
      case (funct3_store_t'(funct3_imm))
        SB: begin
          dmem_wdat_next = {4{rs2_reg[7:0]}};

          unique case (dmem_addr_next[1:0])  //see edubos_pkg.sv for definitions
            2'b00: begin
              dmem_we_next = BYTE1;
            end
            2'b01: begin
              dmem_we_next = BYTE2;
            end
            2'b10: begin
              dmem_we_next = BYTE3;
            end
            2'b11: begin
              dmem_we_next = BYTE4;
            end
          endcase
        end
        SH: begin
          dmem_wdat_next = {2{rs2_reg[15:0]}};

          unique case (dmem_addr_next[1])
            1'b0: begin
              dmem_we_next = HALFWORD1;
            end
            1'b1: begin
              dmem_we_next = HALFWORD2;
            end
          endcase
        end
        SW:      dmem_we_next = WORD;
        default: dmem_we_next = NOWR;
      endcase
    end
    //differentiating between load instructions
    case (funct3_imm)
      LB: begin
        unique case (dmem_addr[1:0])
          2'b00: load_to_reg = {{24{dmem_rdat_reg[7]}}, dmem_rdat_reg[7:0]};
          2'b01: load_to_reg = {{24{dmem_rdat_reg[15]}}, dmem_rdat_reg[15:8]};
          2'b10: load_to_reg = {{24{dmem_rdat_reg[23]}}, dmem_rdat_reg[23:16]};
          2'b11: load_to_reg = {{24{dmem_rdat_reg[31]}}, dmem_rdat_reg[31:24]};
        endcase
      end
      LH: begin
        unique case (dmem_addr[1])
          1'b0: load_to_reg = {{16{dmem_rdat_reg[15]}}, dmem_rdat_reg[15:0]};
          1'b1: load_to_reg = {{16{dmem_rdat_reg[31]}}, dmem_rdat_reg[31:16]};
        endcase
      end
      LW:      load_to_reg = dmem_rdat_reg;
      LBU: begin
        unique case (dmem_addr[1:0])
          2'b00: load_to_reg = {{24{1'b0}}, dmem_rdat_reg[7:0]};
          2'b01: load_to_reg = {{24{1'b0}}, dmem_rdat_reg[15:8]};
          2'b10: load_to_reg = {{24{1'b0}}, dmem_rdat_reg[23:16]};
          2'b11: load_to_reg = {{24{1'b0}}, dmem_rdat_reg[31:24]};
        endcase
      end
      LHU: begin
        unique case (dmem_addr[1])
          1'b0: load_to_reg = {{16{1'b0}}, dmem_rdat_reg[15:0]};
          1'b1: load_to_reg = {{16{1'b0}}, dmem_rdat_reg[31:16]};
        endcase
      end
      default: load_to_reg = dmem_rdat_reg;
    endcase
  end : _load_store

  //--------------
  // Branch detect
  //--------------
  logic take_brnch;
  always_comb begin : _branch
    case (funct3_brnch)
      BEQ:     take_brnch = eq;
      BNE:     take_brnch = !eq;
      BLT:     take_brnch = lt;
      BGE:     take_brnch = !lt;
      BLTU:    take_brnch = ltu;
      BGEU:    take_brnch = !ltu;
      default: take_brnch = eq;
    endcase
  end : _branch

  //-----------------------------------------------------
  // JUMP and Program counter control
  //-----------------------------------------------------

  always_comb begin : _next_pc
    inc_pc   = pc + cpu_pc_t'(1);

    pc_auipc = pc + imm_uload_reg[31:2];
    pc_imm   = pc + (instr[3] ? imm_jump[31:2] : imm_brnch[31:2]);

    unique if (instr_decode_reg.JAL | (instr_decode_reg.BRNCH & take_brnch)) begin
      next_pc = pc_imm_reg;
    end
    else if (instr_decode_reg.JALR) begin
      next_pc = cpu_pc_t'(alu_out[31:2]);
    end
    else begin
      next_pc = inc_pc;
    end
  end : _next_pc

  always_comb begin : _rf_writeback
    rf_we = (state == FETCH_INSTR) & (instr.grp.reg2reg.rd != '0)  //RF[0] is not writable!
    & |{instr_decode_reg.ALUIMM, instr_decode_reg.ALUREG,
              instr_decode_reg.JALR, instr_decode_reg.JAL,
              instr_decode_reg.AUIPC, instr_decode_reg.LUI,
              instr_decode_reg.LOAD & dmem_rdy_reg};  //Dont change to FETCH_INSTR
    unique if (instr_decode_reg.JAL | instr_decode_reg.JALR) begin
      rf_wdat = {inc_pc, 2'd0};  // JUMP: Save return PC address
    end
    else if (instr_decode_reg.AUIPC) begin
      rf_wdat = {pc_auipc, 2'b0};
    end
    else if (instr_decode_reg.LUI) begin
      rf_wdat = imm_uload;  //KEEP AS IS, affects timing
    end
    else if (instr_decode_reg.ALUIMM | instr_decode_reg.ALUREG) begin
      rf_wdat = alu_out;  // ALU*: Save the result of ALU operation
    end
    else begin
      rf_wdat = load_to_reg;  // LOAD: Save the data read from memory, and other
    end

  end : _rf_writeback

  //-------------------------------------------------
  // Execution FSM
  //-------------------------------------------------

  always_ff @(negedge arst_n or posedge clk) begin : _fsm
    if (arst_n == LO) begin
      pc       <= '0;
      state    <= EXECUTE;
      imem_vld <= '1;
    end
    else begin
      case (state)

        FETCH_INSTR: begin
          // IMEM expected to always output in one cycle
          // imem_rdy used just for reading to dmem_rdat from imem_rdat
          pc <= next_pc;
          if (EN_WAIT4REGS == 1) begin
            state    <= WAIT4REGS;
            imem_vld <= 1'b0;
          end
          else begin
            state    <= EXECUTE;
            imem_vld <= 1'b1;
          end
        end

        WAIT4REGS: begin  // MCP=2 for the fetched data
          imem_vld <= 1'b1;
          state    <= EXECUTE;
        end

        LOAD_DATA: begin  // data is loaded in the execute cycle

          imem_vld <= 1'b1;
          // eduSOC compatibility, data is valid for one cycle only in some cases (UART)
          if (dmem_rdy) begin
            state <= FETCH_INSTR;
          end
          else begin
            state <= WAIT_DATA;
          end
        end

        WAIT_DATA: begin

          if (dmem_rdy) begin  // wait for data to be ready
            state <= FETCH_INSTR;
          end
          else begin
            state <= WAIT_DATA;
          end
        end

        EXECUTE: begin

          if (instr_decode.LOAD & ((!dmem_rdy & EN_WAIT4REGS == 1) | EN_WAIT4REGS == 0)) begin
            state <= LOAD_DATA;
          end
          else begin
            if (!instr_decode.SYSTEM) begin
              state    <= FETCH_INSTR;
              imem_vld <= 1'b0;
            end
          end
        end

        default: state <= FETCH_INSTR;
      endcase
    end
  end : _fsm



  //-------------------------------------------------
  // The ALU
  //-------------------------------------------------

  always_comb begin : _alu_inputs
    aluin_1 = rs1;

    // aluin_2 mux
    if (instr_decode.ALUREG | instr_decode.BRNCH) begin
      shamt   = rs2[4:0];
      aluin_2 = rs2;
    end
    else begin
      shamt   = instr.grp.imm.imm11_0[4:0];
      aluin_2 = imm_iload;
    end

  end : _alu_inputs

  edubos5_alu #(
      .GOWIN_FAST_OP(GOWIN_FAST_OP)  //0 for LUT sub/add, 1 for DSP sub/add
  ) u_alu (
      .clk       (clk),                      //i
      .reset     (1'b0),                     //i
      .aluin_1   (aluin_1),                  //i
      .aluin_2   (aluin_2),                  //i
      .shamt     (shamt),                    //i
      .aluimm_dec(instr_decode_reg.ALUIMM),  //i
      .jalr_dec  (instr_decode_reg.JALR),    //i
      .funct7_5  (funct7_alu),               //i
      .funct3    (instr.grp.reg2reg.func3),  //i
      .alu_out   (alu_out),                  //o
      .eq        (eq),                       //o
      .ltu       (ltu),                      //o
      .lt        (lt)                        //o
  );

  //---------------------------------------------------------------------
  // Flopping the interface to dmem: avoid circular logic, increase Fmax
  //---------------------------------------------------------------------


  logic dmem_vld_next;
  assign dmem_vld_next = (|EN_WAIT4REGS & state != WAIT4REGS | ~|EN_WAIT4REGS)
                       & (instr_decode_reg.LOAD & (state == LOAD_DATA | state == WAIT_DATA)
                            & ~dmem_rdy
                          | instr_decode_reg.STORE & state == FETCH_INSTR);

  always_ff @(posedge clk) begin : _dmem_connection
    // data gating
    dmem_addr <= dmem_addr_next;
    if (state == FETCH_INSTR) begin
      dmem_wdat <= dmem_wdat_next;
    end
    dmem_we <= we_bs_t'(dmem_we_next & {4{state == FETCH_INSTR}});
    if (state == WAIT_DATA) begin
      dmem_rdat_reg <= dmem_rdat;
    end

    dmem_rdy_reg <= dmem_rdy;
    dmem_vld     <= dmem_vld_next;

  end : _dmem_connection

endmodule : edubos5
/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2023/08/09 TI: initial creation
*/
