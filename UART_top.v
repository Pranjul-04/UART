module UART_top(
    input clk,
    input reset,
    input tx_start, 
    input [7:0] Data_in,
    output [7:0] Data_out,
    output rx_ready,
    output tx_serial_out,
    input rx_serial_in,
    output status_error
);
    
    wire tx_enb_top;
    wire rx_enb_top;
    wire ready;
    wire parity_error;
    wire frame_error;
    wire tx_busy;

    reg wr_enb;
    reg ready_clr;
    reg [7:0] tx_data_latch; 

    reg [2:0] state, next_state;

    parameter IDLE         = 3'b000;
    parameter WAIT_TX_IDLE = 3'b001;
    parameter SEND         = 3'b010;
    parameter WAIT_RX      = 3'b011;
    parameter CHECK        = 3'b100;

    assign status_error = parity_error | frame_error;
    assign rx_ready = ready;

    baud_rate_generator baud_rate(
        .clk(clk), .rst(reset), .tx_enb(tx_enb_top), .rx_enb(rx_enb_top)
    );

    uart_transmitter tx(
        .clk(clk), .reset(reset), .wr_enb(wr_enb), .tx_enb(tx_enb_top),
        .data_in(tx_data_latch), .tx_serial_data(tx_serial_out), .busy(tx_busy)
    );

    uart_receiver rx(
        .clk(clk), .reset(reset), .rx_enb(rx_enb_top), .ready_clr(ready_clr),
        .rx_serial_data(rx_serial_in), .ready(ready), .data_out(Data_out),
        .parity_error(parity_error), .frame_error(frame_error)
    );

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            state <= IDLE;
            tx_data_latch <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE && tx_start) tx_data_latch <= Data_in;
        end
    end

    always @(*) begin
        next_state = state;
        wr_enb = 0;
        ready_clr = 0;

        case(state)
            IDLE: if(tx_start) next_state = WAIT_TX_IDLE;
            
            WAIT_TX_IDLE: if(!tx_busy) next_state = SEND;

            SEND: begin
                wr_enb = 1;
                next_state = WAIT_RX;
            end

            WAIT_RX: if(ready) next_state = CHECK;

            CHECK: begin
                ready_clr = 1;
                if(status_error) next_state = WAIT_TX_IDLE;
                else next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule
