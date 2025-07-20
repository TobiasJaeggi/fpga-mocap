#ifndef VISIONADDON_APP_UTILS_IACTIVATABLE_H
#define VISIONADDON_APP_UTILS_IACTIVATABLE_H

class IActivatable {
public:
    virtual bool active() = 0;
    virtual void activate() = 0;
    virtual void deactivate() = 0;
};

#endif // VISIONADDON_APP_UTILS_IACTIVATABLE_H