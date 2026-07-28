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
    
    parameter START  = 2'b00;
    parameter DATA   = 2'b01;
    parameter PARITY = 2'b10;
    parameter STOP   = 2'b11;

    reg [1:0] state = START;
    reg [3:0] sample = 0;
    reg [2:0] index = 0;
    reg [7:0] temp = 0;
    
    reg received_parity;
    wire parity_calc = ^temp;

    reg [2:0] filter_samples;
    wire majority_vote = (filter_samples[0] & filter_samples[1]) | 
                         (filter_samples[1] & filter_samples[2]) | 
                         (filter_samples[0] & filter_samples[2]);

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            ready <= 0;
            data_out <= 0;
            parity_error <= 0;
            frame_error <= 0;
            state <= START;
            sample <= 0;
            index <= 0;
            temp <= 0;
            filter_samples <= 3'b111;
        end else begin
            if(ready_clr) ready <= 0;

            if(rx_enb) begin
                case(state)
                    START: begin
                        if(rx_serial_data == 0 || sample != 0) begin
                            sample <= sample + 1'b1;
                            
                            if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                            if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                            if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                            
                            if(sample == 4'd8 && majority_vote == 1'b1) begin
                                sample <= 0;
                                state <= START;
                            end else if(sample == 4'd15) begin
                                state <= DATA;
                                sample <= 0;
                                index <= 0;
                                temp <= 0;
                            end
                        end
                    end

                    DATA: begin
                        sample <= sample + 1'b1;
                        
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) temp[index] <= majority_vote;
                        
                        if(sample == 4'd15) begin
                            sample <= 0;
                            if(index == 3'b111) state <= PARITY;
                            else index <= index + 1'b1;
                        end
                    end

                    PARITY: begin
                        sample <= sample + 1'b1;
                        
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) received_parity <= majority_vote;
                        
                        if(sample == 4'd15) begin
                            sample <= 0;
                            state <= STOP;
                        end
                    end

                    STOP: begin
                        sample <= sample + 1'b1;
                        
                        if(sample == 4'd5) filter_samples[0] <= rx_serial_data;
                        if(sample == 4'd6) filter_samples[1] <= rx_serial_data;
                        if(sample == 4'd7) filter_samples[2] <= rx_serial_data;
                        
                        if(sample == 4'd8) frame_error <= (majority_vote != 1'b1); 
                        
                        if(sample == 4'd15) begin
                            data_out <= temp;
                            ready <= 1'b1;
                            parity_error <= (parity_calc != received_parity);
                            
                            state <= START;
                            sample <= 0;
                        end
                    end
                endcase
            end
        end
    end
endmodule
