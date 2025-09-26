// postprocess.cpp
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <limits>

std::string getLabel(const std::string& labelFile, int index) {
    std::ifstream infile(labelFile);
    std::string line;
    int i = 0;
    while (std::getline(infile, line)) {
        if (i == index) return line;
        i++;
    }
    return "unknown";
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <raw_file> <labels.txt>\n";
        return 2;
    }
    const char* rawPath = argv[1];
    const char* labelPath = argv[2];

    std::ifstream file(rawPath, std::ios::binary);
    if (!file) {
        std::cerr << "ERR: cannot open raw file: " << rawPath << "\n";
        return 3;
    }

    // read float32 values
    std::vector<float> data;
    float tmp;
    while (file.read(reinterpret_cast<char*>(&tmp), sizeof(float))) {
        data.push_back(tmp);
    }
    if (data.empty()) {
        std::cerr << "ERR: raw file has no floats\n";
        return 4;
    }

    int maxIdx = 0;
    float maxVal = data[0];
    for (size_t i = 1; i < data.size(); ++i) {
        if (data[i] > maxVal) { maxVal = data[i]; maxIdx = (int)i; }
    }

    std::string label = getLabel(labelPath, maxIdx);

    // Output in machine-parseable single-line format:
    // <maxValue> <maxIdx> <label>
    std::cout << maxVal << " " << maxIdx << " " << label << "\n";
    return 0;
}
