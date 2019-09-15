## [0.4.0] - 12/05/2019

* BREAKING CHANGE : Removed RubberBottomSheetScope.of() InherithedWidget and moved to RubberBottomSheet.of()
* Improved stability and removed logging

## [0.3.2] - 12/05/2019

* Added method to animate to a certain point animateTo({double from, double to}) and fixed launchTo.

## [0.3.1] - 12/05/2019

* Added substituteScrollController to change the scrollController without setState().
* Fixed issue headerHeight from last release.
* Improved dismissable functionalities.
* Added dragFriction to change the friction when scrolling over bounds.
* Changed header behavior. If header is present it will be possible to drag up and down the bottomsheet only from the peak.
* Removed dismiss method and dismissed state as unnecessary. The dismissable property will use the lowerBound as stopping point. 

## [0.2.9] - 04/05/2019

* Fixed header height without header

## [0.2.8] - 02/05/2019

* Optimized status updates
* Fixed heder overflow, now parameters header and headerHeight are needed
* Improved stability

## [0.2.7] - 15/03/2019

* Changed "value" parameter name to "initialValue" in RubberAnimationController
* Added dismiss() method

## [0.2.6] - 12/01/2019

* Fixed height factor < 0 crash
* Fixed exception if not using a scroll controller
* Improved stability to the launchTo animation

## [0.2.5] - 12/01/2019

* Added header to help manage the bottom sheet with scrolling elements
* Fixed gestures detector inside Scrollable

## [0.2.4] - 08/01/2019

* IOS optimization

## [0.2.3] - 08/01/2019

* Bug fix

## [0.2.2] - 07/01/2019

* Added scroll feature

## [0.2.1] - 26/12/2018

* Added some spring descriptions
* Added new example to show spring settings
* Fixed pixel size initial value

## [0.2.0] - 18/12/2018

* Added dismissable parameter to the animation controller
* Now it is possible to use pixel measures instead of percentages.
* Added the menu example

## [0.1.7] - 17/12/2018

* Fixed example and hiding

## [0.1.6] - 17/12/2018

* Fixed animation value < 0 or > 1

## [0.1.5] - 17/12/2018

* Changed hide/show control and optimized

## [0.1.4] - 17/12/2018

* Changed description and readme

## [0.1.3] - 16/12/2018

* Initial release
