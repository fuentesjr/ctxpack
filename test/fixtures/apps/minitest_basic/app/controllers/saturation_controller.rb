class SaturationController < ApplicationController
  def show
    AlphaOne.call
    BetaTwo.call
    GammaThree.call
    DeltaFour.call
  end
end
