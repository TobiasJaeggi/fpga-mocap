#ifndef VISIONADDON_APP_CALIBRATION_CALIBRATIONMANAGER_H
#define VISIONADDON_APP_CALIBRATION_CALIBRATIONMANAGER_H

#include "utils/constants.h"
#include "utils/matrix/Matrix.h"
#include "storage/IStorage.h"
#include "stm32f7xx_hal.h"

#include <cstdint>

class CalibrationManager final {
public:
    CalibrationManager(IStorage& storage);
    CalibrationManager() = delete;
    CalibrationManager (const CalibrationManager&) = delete;
    CalibrationManager& operator=(const CalibrationManager&) = delete;
    CalibrationManager (const CalibrationManager&&) = delete;
    CalibrationManager& operator=(const CalibrationManager&&) = delete;

    bool restoreToDefaults();
    bool persist(Matrix<3,3>& cameraMatrix);
    bool load(Matrix<3,3>& cameraMatrix);
    bool persist(Matrix<1,5>& distortionCoefficients);
    bool load(Matrix<1,5>& distortionCoefficients);
    enum CalibrationStatus : uint8_t {
        CALIBRATED = 1,
        UNDEFINED = UINT8_MAX,
    };
    CalibrationStatus calibrationStatus();
private:
    bool persist(CalibrationStatus calibrationStatus);
    bool persist(const uint8_t address, const uint8_t* data, size_t size);
    static constexpr uint8_t _ADDRESS_CAMERA_MATRIX {EEPROM_ADDRESS_CAMERA_MATRIX};
    static constexpr uint8_t _ADDRESS_DISTORTION_COEFFICIENTS {EEPROM_ADDRESS_DISTORTION_COEFFICIENTS};
    static constexpr uint8_t _ADDRESS_CALIBRATION_STATUS {EEPROM_CALIBRATION_STATUS};
    IStorage& _storage;

};

#endif // VISIONADDON_APP_CALIBRATION_CALIBRATIONMANAGER_H