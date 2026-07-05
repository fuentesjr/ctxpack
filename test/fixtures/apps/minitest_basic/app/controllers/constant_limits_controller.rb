class ConstantLimitsController < ApplicationController
  def show
    AlphaOne.call
    BetaTwo.call
    GammaThree.call
    DeltaFour.call
    EpsilonFive.call
  end
end
