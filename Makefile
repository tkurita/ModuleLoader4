PRODUCT_NAME := ModuleLoader
CONFIG := Release
DSTROOT = ${HOME}

.PHONY:install clean

default: trash clean install

trash:
	trash ${INSTALL_ROOT}/${INSTALL_PATH}/$(PRODUCT_NAME).scptd
	#trash ${DSTROOT}/Applications/$(PRODUCT_NAME).app

clean:
	xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG) clean
	#xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG) clean DSTROOT=${DSTROOT}

install:
	xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG) install DSTROOT=${DSTROOT}

