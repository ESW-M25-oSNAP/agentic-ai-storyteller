#ifndef UTILS_HPP
#define UTILS_HPP

#include <string>
#include <vector>
#include <cstdint>
#include "json.hpp"

using json = nlohmann::json;

// Base64 encoding
std::string base64_encode(const std::vector<uint8_t>& data);

// Base64 decoding
std::vector<uint8_t> base64_decode(const std::string& encoded);

// Image loading placeholder
std::vector<uint8_t> load_image();

// Image classification placeholder
json classify_image(const std::vector<uint8_t>& image_bytes);

// Image segmentation placeholder
json segment_image(const std::vector<uint8_t>& image_bytes);

#endif // UTILS_HPP