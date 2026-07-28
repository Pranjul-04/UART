module uart_receiver(
    input clk,
    input reset,
    input rx_enb,
    input ready_clr,
    input rx_serial_data,
    
    output reg ready,
    output reg [7:0] data_out,
    output reg parity_error,
    output reg frame_error
);
    
    // UART receiver states
    parameter START  = 2'b00;
    parameter DATA   = 2'b01;
    parameter PARITY = 2'b10;
    parameter STOP   = 2'b11;

    reg [1:0] state = START; // Current receiver state
    reg [3:0] sample = 0; // Sampling counter for 16x oversampling
    reg [2:0] index = 0; // Data bit position counter
    reg [7:0] temp = 0; // Temporary data storage
    
    reg received_parity; // Received parity bit
    wire parity_calc = ^temp; // Calculated parity from received data

    reg [2:0] filter_samples; // Samples used for majority voting

    // Majority voting logic for noise filtering
    wire majority_vote = (filter_samples[0] & filter_samples[1]) | 
                         (filter_samples[1] & filter_samples[2]) | 
                         (filter_samples[0] & filter_samples[2]);

    // Receiver sequential logic
    always @(posedge clk or posedge reset) begin

        // Reset receiver
        if(reset) begin
            ready <= 0;
            data_out <= 0;
            parity_error <= 0;
            frame_error <= 0;
            state <= START;
            sample <= 0;
            index <= 0;
            temp <= 0;

            // Idle UART line is high
            filter_samples <= 3'b111;
        end else begin

            // Clear ready flag after data is processed
            if(ready_clr) ready <= 0;

            // Receiver operates on enable pulse
            if(rx_enb) begin
                case(state)

                    // Detect start bit
                    START: begin
                        if(rx_serial_data == 0 || sample != 0) begin
                            sample <= sample + 1'b1;

                            // Store samples around middle point
                            if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                            if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                            if(sample == 4'd7) filter_samples[2] <= rx_serial_data;

                            // Invalid start bit detection
                            if(sample == 4'd8 && majority_vote == 1'b1) begin
                                sample <= 0;
                                state <= START;
                            end
                            
                            // Move to data reception
                            else if(sample == 4'd15) begin
                                state <= DATA;
                                sample <= 0;
                                index <= 0;
                                temp <= 0;
                            end
                        end
                    end

                    // Receive 8 data bits
                    DATA: begin
                        sample <= sample + 1'b1;

                        // Capture majority samples
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data; 
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) temp[index] <= majority_vote; // Store received bit

                        // Move to next bit
                        if(sample == 4'd15) begin
                            sample <= 0;
                            if(index == 3'b111) state <= PARITY;
                            else index <= index + 1'b1;
                        end
                    end

                    // Receive parity bit
                    PARITY: begin
                        sample <= sample + 1'b1;

                        // Capture parity samples
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) received_parity <= majority_vote; // Store received parity

                        // Move to stop bit
                        if(sample == 4'd15) begin
                            sample <= 0;
                            state <= STOP;
                        end
                    end

                    // Verify stop bit and complete reception
                    STOP: begin
                        sample <= sample + 1'b1;

                        // Capture stop bit samples
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) frame_error <= (majority_vote != 1'b1); // Check stop bit validity

                        // Finish receiving byte
                        if(sample == 4'd15) begin
                            data_out <= temp;
                            ready <= 1'b1; // Indicate received data available
                            parity_error <= (parity_calc != received_parity); // Check parity correctness
                            
                            state <= START;
                            sample <= 0;
                        end
                    end
                endcase
            end
        end
    end
endmodule
