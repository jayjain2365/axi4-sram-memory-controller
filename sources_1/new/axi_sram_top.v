module axi4_sram_top (
    input wire clk,
    input wire rst,
    // Convert active-high top-level reset
// to active-low reset for child modules
   
    // AXI Write Address Channel
    input wire [31:0] s_axi_awaddr,
    input wire [7:0]  s_axi_awlen,
    input wire [2:0]  s_axi_awsize,
    input wire [1:0]  s_axi_awburst,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,

    // AXI Write Data Channel
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire        s_axi_wlast,
    input wire        s_axi_wvalid,
    output wire       s_axi_wready,

    // AXI Write Response Channel
    output wire [1:0] s_axi_bresp,
    output wire       s_axi_bvalid,
    input wire        s_axi_bready,

    // AXI Read Address Channel
    input wire [31:0] s_axi_araddr,
    input wire [7:0]  s_axi_arlen,
    input wire [2:0]  s_axi_arsize,
    input wire [1:0]  s_axi_arburst,
    input wire        s_axi_arvalid,
    output wire       s_axi_arready,

    // AXI Read Data Channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output wire        s_axi_rvalid,
    input wire        s_axi_rready
);
    wire rst_n;
    assign rst_n = ~rst;
    // Transaction ownership
    localparam OWNER_IDLE  = 2'b00;
    localparam OWNER_WRITE = 2'b01;
    localparam OWNER_READ  = 2'b10;

    reg [1:0] owner;

    // Internal AXI address-channel signals
    wire wr_awvalid;
    wire wr_awready;
    wire rd_arvalid;
    wire rd_arready;

    assign wr_awvalid = s_axi_awvalid && (owner == OWNER_IDLE);
    assign rd_arvalid = s_axi_arvalid &&
                        (owner == OWNER_IDLE) &&
                        !s_axi_awvalid;

    assign s_axi_awready = (owner == OWNER_IDLE) && wr_awready;
    assign s_axi_arready = (owner == OWNER_IDLE) &&
                           !s_axi_awvalid && rd_arready;

    // Write slave to SRAM interface
    wire wr_sram_req;
    wire wr_sram_we;
    wire [7:0]  wr_sram_addr;
    wire [31:0] wr_sram_wdata;
    wire [3:0]  wr_sram_be;
    wire wr_sram_ready;
    wire wr_sram_done;

    // Read slave to SRAM interface
    wire rd_sram_req;
    wire rd_sram_we;
    wire [7:0]  rd_sram_addr;
    wire [31:0] rd_sram_rdata;
    wire rd_sram_ready;
    wire rd_sram_done;

    // Shared SRAM controller interface
    wire sram_req;
    wire sram_we;
    wire [7:0]  sram_addr;
    wire [31:0] sram_wdata;
    wire [3:0]  sram_be;
    wire sram_ready;
    wire sram_done;
    wire [31:0] sram_rdata;
    // SRAM memory-side interface
    wire        mem_en;
    wire        mem_we;
    wire [7:0]  mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire [31:0] mem_rdata;
    // Only the current owner receives SRAM handshake signals
    assign wr_sram_ready = (owner == OWNER_WRITE) && sram_ready;
    assign wr_sram_done  = (owner == OWNER_WRITE) && sram_done;

    assign rd_sram_ready = (owner == OWNER_READ) && sram_ready;
    assign rd_sram_done  = (owner == OWNER_READ) && sram_done;

    assign rd_sram_rdata = sram_rdata;

    // Shared SRAM request selection
    assign sram_req = (owner == OWNER_WRITE) ? wr_sram_req :
                      (owner == OWNER_READ)  ? rd_sram_req :
                      1'b0;

    assign sram_we = (owner == OWNER_WRITE) ? wr_sram_we :
                     (owner == OWNER_READ)  ? rd_sram_we :
                     1'b0;

    assign sram_addr = (owner == OWNER_WRITE) ? wr_sram_addr :
                       (owner == OWNER_READ)  ? rd_sram_addr :
                       8'b0;

    assign sram_wdata = (owner == OWNER_WRITE) ? wr_sram_wdata :
                        32'b0;

    assign sram_be = (owner == OWNER_WRITE) ? wr_sram_be :
                     4'b0;

    // AXI4 Write Slave
    axi4_write_slave WRITE_SLAVE (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(wr_awvalid),
        .s_axi_awready(wr_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .sram_req(wr_sram_req),
        .sram_we(wr_sram_we),
        .sram_addr(wr_sram_addr),
        .sram_wdata(wr_sram_wdata),
        .sram_be(wr_sram_be),
        .sram_ready(wr_sram_ready),
        .sram_done(wr_sram_done)
    );

    // AXI4 Read Slave
    axi4_read_slave READ_SLAVE (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(rd_arvalid),
        .s_axi_arready(rd_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .sram_req(rd_sram_req),
        .sram_we(rd_sram_we),
        .sram_addr(rd_sram_addr),
        .sram_ready(rd_sram_ready),
        .sram_done(rd_sram_done),
        .sram_rdata(rd_sram_rdata)
    );

    // Single shared SRAM controller
    sram_controller SRAM_CONTROLLER (
    .clk(clk),
    .rst_n(rst_n),

    // Request interface
    .req(sram_req),
    .we(sram_we),
    .addr(sram_addr),
    .wdata(sram_wdata),
    .be(sram_be),
    .ready(sram_ready),
    .done(sram_done),
    .rdata(sram_rdata),

    // Memory interface
    .mem_en(mem_en),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_be(mem_be),
    .mem_rdata(mem_rdata)
);
    sram_256x32_model SRAM_MEMORY (
    .clk(clk),
    .mem_en(mem_en),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_be(mem_be),
    .mem_rdata(mem_rdata)
);

    // Global transaction ownership
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            owner <= OWNER_IDLE;
        end
        else begin
            case (owner)

                OWNER_IDLE: begin
                    // Write has priority if both requests arrive together
                    if (s_axi_awvalid && s_axi_awready)
                        owner <= OWNER_WRITE;
                    else if (s_axi_arvalid && s_axi_arready)
                        owner <= OWNER_READ;
                end

                OWNER_WRITE: begin
                    // Release SRAM after write response handshake
                    if (s_axi_bvalid && s_axi_bready)
                        owner <= OWNER_IDLE;
                end

                OWNER_READ: begin
                    // Release SRAM after final read beat handshake
                    if (s_axi_rvalid && s_axi_rready && s_axi_rlast)
                        owner <= OWNER_IDLE;
                end

                default: owner <= OWNER_IDLE;

            endcase
        end
    end

endmodule
