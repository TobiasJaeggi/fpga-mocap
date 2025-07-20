#ifndef VISIONADDON_APP_UTILS_MATRIX_MATRIX_H
#define VISIONADDON_APP_UTILS_MATRIX_MATRIX_H

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <tuple>

// m rows, n cols, indexing starts at 1
template <int m, int n>
class Matrix {
public:
    Matrix();
    Matrix(std::array<float, m * n> data);
    Matrix (const Matrix&) = delete;
    Matrix& operator=(const Matrix&) = delete;
    Matrix (const Matrix&&) = delete;
    Matrix& operator=(const Matrix&&) = delete;
    bool get(float& dst, int row, int col); //!< get value
    bool set(float src, int row, int col); //!< set value
    bool getRow(std::array<float, n>& dst, int row); //!< get row
    bool setRow(std::array<float, n>& src, int row); //!< set row
    bool getCol(std::array<float, m>& dst, int col); //!< set col
    bool setCol(std::array<float, m>& src, int col); //!< set col
    std::tuple<bool, size_t> toBytes(uint8_t* buffer, size_t size);
    bool fromBytes(const uint8_t* buffer, size_t size);
    const std::array<float, m * n>& data() {return _data;};
    static constexpr size_t SIZE() {return (m * n) * sizeof(float);}; 
    static constexpr int ROWS(){return m;};
    static constexpr int COLS(){return n;};
    static constexpr std::tuple<int,int> SHAPE(){return {ROWS(),COLS()};};
private:
    std::array<float, m * n> _data {};
    static constexpr int COLS_PER_ROW(){return COLS();}; // wrapper to improve readability
    static constexpr int ROWS_PER_COL(){return ROWS();}; // wrapper to improve readability
};


template <int m, int n>
Matrix<m,n>::Matrix()
{
    static_assert(SIZE() == sizeof(_data));
}

template <int m, int n>
Matrix<m,n>::Matrix(std::array<float, m * n> data):
_data{std::move(data)}
{
    static_assert(SIZE() == sizeof(_data));
}

template <int m, int n>
bool Matrix<m,n>::get(float& dst, int row, int col) {
    if((row > ROWS()) || col > COLS()){
        return false;
    }
    row--;
    col--;
    dst = _data.at((row * COLS_PER_ROW()) + col);
    return true;
}

template <int m, int n>
bool Matrix<m,n>::set(float src, int row, int col) {
    if((row > ROWS()) || col > COLS()){
        return false;
    }
    row--;
    col--;
    _data.at((row * COLS_PER_ROW()) + col) = src;
    return true;
}

template <int m, int n>
bool Matrix<m,n>::getRow(std::array<float, n>& dst, int row) {
    if(row > ROWS()){
        return false;
    }
    row--;
    std::copy(dst.begin(), dst.end(), _data.begin() + row * COLS_PER_ROW());
    return true;
}

template <int m, int n>
bool Matrix<m,n>::setRow(std::array<float, n>& src, int row) {
    if(row > ROWS()){
        return false;
    }
    row--;
    const auto begin = _data.begin() + (row * COLS_PER_ROW());
    const auto end = _data.begin() + (row * COLS_PER_ROW()) + COLS_PER_ROW();
    std::copy(begin, end, src.begin());
    return true;
}

template <int m, int n>
bool Matrix<m,n>::getCol(std::array<float, m>& dst, int col) {
    if(col > COLS()){
        return false;
    }
    col--;
    std::copy(dst.begin(), dst.end(), _data.begin() + col * ROWS_PER_COL());
    return true;
}

template <int m, int n>
bool Matrix<m,n>::setCol(std::array<float, m>& src, int col) {
    if(col > COLS()){
        return false;
    }
    col--;
    const auto begin = _data.begin() + (col * ROWS_PER_COL());
    const auto end = _data.begin() + (col * ROWS_PER_COL()) + ROWS_PER_COL();
    std::copy(begin, end, src.begin());
    return true;
}

template <int m, int n>
std::tuple<bool, size_t> Matrix<m,n>::toBytes(uint8_t* buffer, size_t size){
    if(size < SIZE()){
        return {false, 0};
    }
    std::memcpy(buffer, _data.data(), SIZE());
    return {true, SIZE()};
}

template <int m, int n>
bool Matrix<m,n>::fromBytes(const uint8_t* buffer, size_t size){
    if(size != SIZE()){
        return false;
    }
    std::memcpy(_data.data(), buffer, SIZE());
    return true;
}

#endif // VISIONADDON_APP_UTILS_MATRIX_MATRIX_H