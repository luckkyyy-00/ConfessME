package com.confess.app.confess_app

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactory(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.list_tile_native_ad, null) as NativeAdView

        // Map views
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)

        // Populate views
        (adView.headlineView as TextView).text = nativeAd.headline
        adView.bodyView?.let {
            if (nativeAd.body == null) {
                it.visibility = View.INVISIBLE
            } else {
                it.visibility = View.VISIBLE
                (it as TextView).text = nativeAd.body
            }
        }

        adView.callToActionView?.let {
            if (nativeAd.callToAction == null) {
                it.visibility = View.INVISIBLE
            } else {
                it.visibility = View.VISIBLE
                (it as Button).text = nativeAd.callToAction
            }
        }

        adView.iconView?.let {
            if (nativeAd.icon == null) {
                it.visibility = View.GONE
            } else {
                (it as ImageView).setImageDrawable(nativeAd.icon?.drawable)
                it.visibility = View.VISIBLE
            }
        }

        // Set the ad object
        adView.setNativeAd(nativeAd)

        return adView
    }
}
