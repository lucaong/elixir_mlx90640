#include <stdint.h>
#include <iostream>
#include <cstring>
#include <fstream>
#include <chrono>
#include <thread>
#include <err.h>
#include <errno.h>
#include <math.h>
#include "MLX90640_API.h"

#define MLX_I2C_ADDR 0x33

// Despite the framerate being ostensibly FPS hz The frame is often not ready in
// time This offset is added to the frame time microseconds to account for this.
#define OFFSET_MICROS 850

#define PIXELS 768

void write_fixed(uint8_t *msg, int len) {
  int written = 0;
  while(written < len) {
    int this_write = fwrite(msg + written, sizeof(uint8_t), len - written, stdout);
    if (this_write <= 0 && errno != EINTR) {
      err(EXIT_FAILURE, "%s: %d", "writing data", this_write);
    }
    written += this_write;
  }
}

void measurement_to_bytes(float *measurement, uint8_t *buffer) {
  for (int i = 0; i < PIXELS; i++) {
    double integral;
    double fraction = modf(measurement[i], &integral);
    uint8_t sign = (integral < 0 ? 1 : 0) << 7;
    buffer[i * 2] = (uint8_t) abs((int) integral);
    buffer[i * 2 + 1] = ((uint8_t) ((int) (fraction * 100)) | sign);
  }
}

// Output measurement, prefixed with 2-byte length header (to be read by
// Erlang/Elixir Port).
//
// Each measured pixel is composed of 2 bytes, with the following meaning:
// Byte 1: absolute value of the integer part of the temperature
// Byte 2: the first bit is the sign of the integer part (0 = +, 1 = -), the
// remaining 7 bits are the fractional part, with 2 digits precision
//
// Example:
// 21.87 -> 0b00010101 0b01010111
// -21.87 -> 0b00010101 0b11010111
void output_measurement(float *measurement) {
  uint8_t msg[PIXELS * 2];
  measurement_to_bytes(measurement, msg);
  unsigned long len = PIXELS * 2;
  uint8_t size_header[2] = {(uint8_t) (len >> 8 & 0xff), (uint8_t) (len & 0xff)};
  write_fixed(size_header, 2);
  write_fixed(msg, len);
}

int main(int argc, char *argv[]) {
  static uint16_t eeMLX90640[832];
  float emissivity = 1;
  uint16_t frame[834];
  static float mlx90640To[PIXELS];
  float eTa;
  int fps = 2;

  if (argc > 1) {
    fps = atoi(argv[1]);
  }

  MLX90640_SetControlRegister(MLX_I2C_ADDR, 0b0001101000000001);

  if (fps == 1) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b001);
  } else if (fps == 2) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b010);
  } else if (fps == 4) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b011);
  } else if (fps == 8) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b100);
  } else if (fps == 16) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b101);
  } else if (fps == 32) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b110);
  } else if (fps == 64) {
    MLX90640_SetRefreshRate(MLX_I2C_ADDR, 0b111);
  } else {
    printf("Unsupported framerate: %d", fps);
    return 1;
  }
  
  auto frame_time = std::chrono::microseconds(1000000 / fps + OFFSET_MICROS);

  MLX90640_SetChessMode(MLX_I2C_ADDR);

  paramsMLX90640 mlx90640;
  MLX90640_DumpEE(MLX_I2C_ADDR, eeMLX90640);
  MLX90640_ExtractParameters(eeMLX90640, &mlx90640);

  while (1) {
    auto start = std::chrono::system_clock::now();
    MLX90640_GetFrameData(MLX_I2C_ADDR, frame);

    eTa = MLX90640_GetTa(frame, &mlx90640);
    MLX90640_CalculateTo(frame, &mlx90640, emissivity, eTa, mlx90640To);

    output_measurement(mlx90640To);

    auto end = std::chrono::system_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::this_thread::sleep_for(std::chrono::microseconds(frame_time - elapsed));
  }

  return 0;
}
