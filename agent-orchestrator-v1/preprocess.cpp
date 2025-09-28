#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <filesystem>
#include <opencv2/opencv.hpp>

// default mean RGB values
const cv::Scalar MEAN_RGB(128.0, 128.0, 128.0);
const float DIVISOR = 128.0f;

namespace fs = std::filesystem;

// center crop to square
cv::Mat center_crop_square(const cv::Mat& img) {
    int width = img.cols;
    int height = img.rows;
    int short_dim = std::min(width, height);
    int x = (width - short_dim) / 2;
    int y = (height - short_dim) / 2;
    cv::Rect roi(x, y, short_dim, short_dim);
    return img(roi);
}

// resize with method: "bilinear" or "antialias"
cv::Mat resize_img(const cv::Mat& img, int size, const std::string& resize_type) {
    cv::Mat dst;
    int interp = (resize_type == "bilinear") ? cv::INTER_LINEAR : cv::INTER_AREA;
    cv::resize(img, dst, cv::Size(size, size), 0, 0, interp);
    return dst;
}

// convert to raw float32 and save
void save_raw(const cv::Mat& img_bgr, const std::string& raw_path, bool save_uint8=false) {
    cv::Mat img_float;
    img_bgr.convertTo(img_float, CV_32FC3);

    // subtract mean
    img_float -= MEAN_RGB;
    img_float /= DIVISOR;

    if (save_uint8) {
        img_float.convertTo(img_float, CV_8UC3);
    }

    std::ofstream fout(raw_path, std::ios::binary);
    if (!fout) {
        std::cerr << "ERR: cannot open raw file for writing: " << raw_path << "\n";
        return;
    }
    fout.write(reinterpret_cast<const char*>(img_float.data),
               img_float.total() * img_float.elemSize());
    fout.close();
}

// full pipeline for one image
void process_image(const std::string& src_path,
                   const std::string& dest_jpg_path,
                   int size,
                   const std::string& resize_type) {
    cv::Mat img = cv::imread(src_path, cv::IMREAD_COLOR);
    if (img.empty()) {
        std::cerr << "ERR: cannot read image: " << src_path << "\n";
        return;
    }

    cv::Mat cropped = center_crop_square(img);
    cv::Mat resized = resize_img(cropped, size, resize_type);

    // save resized jpg
    cv::imwrite(dest_jpg_path, resized);

    // save raw
    std::string raw_path = dest_jpg_path.substr(0, dest_jpg_path.find_last_of(".")) + ".raw";
    save_raw(resized, raw_path, false);
}

int main(int argc, char* argv[]) {
    if (argc < 5) {
        std::cerr << "Usage: " << argv[0] << " <img_folder> <dest_folder> <size> <resize_type>\n";
        return 1;
    }

    std::string src_dir = argv[1];
    std::string dest_dir = argv[2];
    int size = std::stoi(argv[3]);
    std::string resize_type = argv[4];
    if (resize_type != "bilinear" && resize_type != "antialias") {
        std::cerr << "resize_type must be 'bilinear' or 'antialias'\n";
        return 2;
    }

    fs::create_directories(dest_dir);

    std::cout << "Converting images for inception v3 network.\n";
    for (auto& p : fs::recursive_directory_iterator(src_dir)) {
        if (p.is_regular_file()) {
            std::string ext = p.path().extension().string();
            if (ext == ".jpg" || ext == ".jpeg" || ext == ".JPG" || ext == ".JPEG") {
                std::string dest_path = fs::path(dest_dir) / p.path().filename();
                std::cout << "Processing: " << p.path() << "\n";
                process_image(p.path().string(), dest_path, size, resize_type);
            }
        }
    }
    return 0;
}
