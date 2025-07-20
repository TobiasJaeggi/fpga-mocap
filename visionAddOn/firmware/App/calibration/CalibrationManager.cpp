#include "CalibrationManager.h"
#include "utils/Log.h"

#include <cstring>

CalibrationManager::CalibrationManager(IStorage& storage) :
_storage{storage}
{
};

bool CalibrationManager::restoreToDefaults() {
    return persist(CalibrationStatus::UNDEFINED);
    //TODO: blink
}

bool CalibrationManager::persist(Matrix<3,3>& cameraMatrix) {
    //TODO
    persist(_ADDRESS_CAMERA_MATRIX, cameraMatrix.data().data(), std::remove_reference_t<decltype(cameraMatrix)>::SIZE());
    return false;
}

bool CalibrationManager::load(Matrix<3,3>& cameraMatrix) {
    //TODO
    return false;
}

bool CalibrationManager::persist(Matrix<1,5>& distortionCoefficients) {
    //TODO
    return false;
}

bool CalibrationManager::load(Matrix<1,5>& distortionCoefficients) {
    //TODO
    return false;
}

CalibrationManager::CalibrationStatus CalibrationManager::calibrationStatus() {
    //TODO
    return CalibrationStatus::UNDEFINED;
}

bool CalibrationManager::persist(CalibrationStatus calibrationStatus) {
    //TODO
    return false;
}

bool CalibrationManager::persist(const uint8_t address, const uint8_t* data, size_t size) {
    //TODO
    static constexpr size_t MAX_RETRIES {5};    
    size_t retries {0};
    for(; retries < MAX_RETRIES; retries++){
        if(!_storage.isBusy()){
            break;
        }
        static constexpr uint32_t DELAY_MS {1};
        HAL_Delay(DELAY_MS * TICKS_PER_MILLISECOND); // intentionally blocking
    }
    if(retries == MAX_RETRIES){ // still busy
        Log::warning("[NetworkManager] storage busy");
        return false;
    }
    return _storage.writeData(address, data);        
}