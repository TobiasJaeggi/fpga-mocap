#ifndef VISIONADDON_APP_UTILS_ITRANSFER_H
#define VISIONADDON_APP_UTILS_ITRANSFER_H

class ITransfer {
public:
    virtual bool isActive() = 0;
    virtual void start() = 0;
};

#endif // VISIONADDON_APP_UTILS_ITRANSFER_H