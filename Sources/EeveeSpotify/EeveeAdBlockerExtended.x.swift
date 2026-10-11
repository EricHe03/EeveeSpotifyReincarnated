// TESTING: extended ad blocker for Swift Service-based ad surfaces
// (Evo home brand-ads, NPV under-player ad, in-stream audio, native ads).
// Hooks SPTService -load on each ad service and skips orig so the service
// stays inert. Per-surface bool flips below if one needs disabling.

import Orion
import Foundation
import UIKit
import ObjectiveC.runtime

// Every service has its own group. Spotify rolls these modules out
// independently, so one missing/renamed class must not disable the rest of the
// blocker on sideloaded/rootless builds either.
struct AdsServiceImplGroup: HookGroup {}
struct InStreamAdsServiceGroup: HookGroup {}
struct EmbeddedNPVServiceGroup: HookGroup {}
struct LeavebehindAdsBaseServiceGroup: HookGroup {}
struct LeavebehindAdsBaseInternalServiceGroup: HookGroup {}
struct SponsoredContextServiceGroup: HookGroup {}
struct SponsoredContextNPBAttachmentServiceGroup: HookGroup {}
struct SponsoredPlaylistHeaderServiceGroup: HookGroup {}
struct SponsoredPlaylistHeaderViewGroup: HookGroup {}
struct NativeAdsLoggerServiceGroup: HookGroup {}
struct SponsoredCtxAttachmentGroup: HookGroup {}
struct ScrollFeedAdViewGroup: HookGroup {}
struct ScrollFeedAdServiceGroup: HookGroup {}
struct ScrollFeedAdControllerGroup: HookGroup {}
struct AdsStandaloneServiceGroup: HookGroup {}
struct NativeAdsServiceGroup: HookGroup {}
struct AdsSurveyViewGroup: HookGroup {}

private let killAdsServiceImpl         = true
private let killInStreamAdsService     = true
private let killEmbeddedNPVService     = true
private let killNativeAdsLoggerService = true
private let killSponsoredCtxAttachment = true
private let logAdBlockerEvents         = true

@inline(__always)
private func adlog(_ what: String) {
    if logAdBlockerEvents {
        writeDebugLog("[AdBlock] suppressed \(what)")
    }
}

// Activation diagnostics also go to the debug file — NSLog alone never
// reached the tester log and hid whether hooks actually attached.
private func ablog(_ message: String) {
    writeDebugLog("[AdBlock] \(message)")
}

// Orion's GroupRegistry treats a second activation of the same group as a
// NON-RECOVERABLE error — `activate()` -> `orionError("Group ... has already
// been activated")` -> the global handler, which defaults to `fatalError`.
// Several ad surfaces here deliberately share one group, so every activation
// must be guarded. Unguarded, the tweak crashes at launch the moment two
// classes sharing a group are both present, which 9.1.90 guarantees.
@inline(__always)
private func activateOnce<G: HookGroup>(_ group: G.Type, _ create: () -> G) {
    guard !group.isActive else { return }
    create().activate()
}

// Swift classes register in the ObjC runtime lazily, so NSClassFromString at
// tweak-init time can miss classes that exist (build-3 tester log: every
// scroll-feed service kill skipped as "unavailable" while the ad rendered).
// Brute-force the registered class list as a fallback, cached after the first
// scan so every activation lookup shares one pass.
private var classListByNameCache: [String: AnyClass] = [:]
private var classListByNameCacheBuilt = false

func findTweakClass(_ name: String) -> AnyClass? {
    if let cls = NSClassFromString(name) { return cls }
    if classListByNameCacheBuilt { return classListByNameCache[name] }
    // objc_copyClassList returns AutoreleasingUnsafeMutablePointer; subscripting
    // triggers retain/autorelease msgSend which aborts on iOS 26+ (same trap as
    // EeveeProbes). objc_getClassList with a raw buffer sidesteps it.
    let total = objc_getClassList(nil, 0)
    guard total > 0 else { return nil }
    let buf = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(total))
    defer { buf.deallocate() }
    let n = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(buf), total)
    for i in 0..<Int(n) {
        let raw = UnsafeRawPointer(buf).load(fromByteOffset: i * MemoryLayout<UnsafeRawPointer>.size,
                                              as: UnsafeRawPointer.self)
        let cls = unsafeBitCast(raw, to: AnyClass.self)
        classListByNameCache[String(cString: class_getName(cls))] = cls
    }
    classListByNameCacheBuilt = true
    return classListByNameCache[name]
}

class AdsServiceImplKill: ClassHook<NSObject> {
    typealias Group = AdsServiceImplGroup
    static let targetName: String = "_TtC19AdsPlatform_AdsImpl14AdsServiceImpl"
    func load() {
        if killAdsServiceImpl { adlog("AdsServiceImpl.load"); return }
        orig.load()
    }
}

class InStreamAdsServiceKill: ClassHook<NSObject> {
    typealias Group = InStreamAdsServiceGroup
    static let targetName: String = "_TtC29AdsNowPlaying_InStreamAdsImpl18InStreamAdsService"
    func load() {
        if killInStreamAdsService { adlog("InStreamAdsService.load"); return }
        orig.load()
    }
}

class EmbeddedNPVServiceImplKill: ClassHook<NSObject> {
    typealias Group = EmbeddedNPVServiceGroup
    static let targetName: String = "_TtC29AdsNowPlaying_EmbeddedNPVImpl22EmbeddedNPVServiceImpl"
    func load() {
        if killEmbeddedNPVService { adlog("EmbeddedNPVServiceImpl.load"); return }
        orig.load()
    }
}

// Spotify 9.1.66+ can render the under-player card through a separate
// "unified leavebehind" pipeline. It does not depend on EmbeddedNPVServiceImpl.
class LeavebehindAdsBaseServiceKill: ClassHook<NSObject> {
    typealias Group = LeavebehindAdsBaseServiceGroup
    static let targetName: String =
        "_TtC36AdsStandalone_LeavebehindAdsBaseImpl25LeavebehindAdsBaseService"

    func load() {
        adlog("LeavebehindAdsBaseService.load")
        return
    }
}

class LeavebehindAdsBaseInternalServiceKill: ClassHook<NSObject> {
    typealias Group = LeavebehindAdsBaseInternalServiceGroup
    static let targetName: String =
        "_TtC36AdsStandalone_LeavebehindAdsBaseImpl33LeavebehindAdsBaseInternalService"

    func load() {
        adlog("LeavebehindAdsBaseInternalService.load")
        return
    }
}

// Native sponsored surfaces are separate from AdsServiceImpl in 9.1.x.
// Blocking their SPTService entry points keeps sponsored headers and the
// Now Playing Bar attachment from being constructed at all.
class SponsoredContextServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredContextServiceGroup
    static let targetName =
        "_TtC35AdsEmbedded_AdsSponsoredContextImpl30AdsSponsoredContextServiceImpl"

    func load() {
        adlog("AdsSponsoredContextServiceImpl.load")
        return
    }
}

class SponsoredContextNPBAttachmentServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredContextNPBAttachmentServiceGroup
    static let targetName =
        "_TtC48AdsEmbedded_AdsSponsoredContextNPBAttachmentImpl43AdsSponsoredContextNPBAttachmentServiceImpl"

    func load() {
        adlog("AdsSponsoredContextNPBAttachmentServiceImpl.load")
        return
    }
}

class SponsoredPlaylistHeaderServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredPlaylistHeaderServiceGroup
    static let targetName =
        "_TtC42AdsEmbedded_AdsSponsoredPlaylistHeaderImpl37AdsSponsoredPlaylistHeaderServiceImpl"

    func load() {
        adlog("AdsSponsoredPlaylistHeaderServiceImpl.load")
        return
    }
}

// Rendering fallback for a sponsored header that was already materialized
// before its service hook became active. Generic Spotify banners stay intact.
class SponsoredPlaylistHeaderViewKill: ClassHook<UIView> {
    typealias Group = SponsoredPlaylistHeaderViewGroup
    static let targetName =
        "_TtC18AdsPlatform_ECMKit37AdsSponsoredPlaylistHeaderCentralView"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        target.isHidden = true
        target.isUserInteractionEnabled = false
        if target.superview != nil {
            adlog("AdsSponsoredPlaylistHeaderCentralView")
            target.removeFromSuperview()
        }
    }
}

class NativeAdsLoggerServiceImplKill: ClassHook<NSObject> {
    typealias Group = NativeAdsLoggerServiceGroup
    static let targetName: String = "_TtC20NativeAds_LoggerImpl26NativeAdsLoggerServiceImpl"
    func load() {
        if killNativeAdsLoggerService { adlog("NativeAdsLoggerServiceImpl.load"); return }
        orig.load()
    }
}

// Passive log only — returning nil from init would crash the alloc chain.
// Upstream events are starved by killing AdsServiceImpl above.
class SponsoredCtxAttachmentProbe: ClassHook<NSObject> {
    typealias Group = SponsoredCtxAttachmentGroup
    static let targetName: String =
        "_TtC48AdsEmbedded_AdsSponsoredContextNPBAttachmentImpl25AdModelChangedEventSource"
    func `init`() -> Target {
        if killSponsoredCtxAttachment {
            adlog("SponsoredCtxAttachment.init (passive)")
        }
        return orig.`init`()
    }
}

// Now Playing scroll-feed ad card ("Montblanc Legend Elixir · Adverti…" in the
// scrollsita/NPV feed). The feed payload (spotify.scrollsita.v1.EmbeddedAd /
// ImageBrandAd) is rendered by EmbeddedAdAdapterElementUI, and
// EmbeddedCTAElementsServiceImpl provisions the embedded-CTA/ad adapter tree.
// Same hide-on-attach pattern as SponsoredPlaylistHeaderViewKill above.
class EmbeddedAdAdapterElementUIKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdViewGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl26EmbeddedAdAdapterElementUI"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("EmbeddedAdAdapterElementUI (scroll-feed ad card)")
            view.removeFromSuperview()
        }
    }
}

class EmbeddedCTAElementsServiceImplKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdServiceGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl30EmbeddedCTAElementsServiceImpl"

    func load() {
        adlog("EmbeddedCTAElementsServiceImpl.load")
    }
}

// Second scroll-feed pipeline: EmbeddedAdControllerServiceImpl wires the
// scrollsita EmbeddedAd/ImageBrandAd payloads into renderable ad elements.
// Starving it covers the case where the CTA service path is bypassed.
class EmbeddedAdControllerServiceImplKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC36AdsEmbedded_EmbeddedAdControllerImpl31EmbeddedAdControllerServiceImpl"

    func load() {
        adlog("EmbeddedAdControllerServiceImpl.load")
    }
}

// Broader embedded-ad pipeline kills (every name verified in the 9.1.84
// binary). The scroll card rendered despite the EmbeddedAdAdapterElementUI
// view kill, so the pipeline is starved one layer deeper and sibling render
// paths are covered too.
class EmbeddedAdAdapterElementProviderKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl32EmbeddedAdAdapterElementProvider"

    func load() {
        adlog("EmbeddedAdAdapterElementProvider.load")
    }
}

// Playlist-feed ad controllers (EmbeddedAd sections injected into playlist
// scroll contexts; sibling pipeline of the NPV scroll feed).
class PlaylistAdControllerV2Kill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC32AdsEmbedded_EmbeddedPlaylistImpl22PlaylistAdControllerV2"

    func load() {
        adlog("PlaylistAdControllerV2.load")
    }
}

class PlaylistAdControllerImplKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC32AdsEmbedded_EmbeddedPlaylistImpl24PlaylistAdControllerImpl"

    func load() {
        adlog("PlaylistAdControllerImpl.load")
    }
}

// Leavebehind ad elements under the player (EmbeddedAdPresentationKit).
class LeavebehindAdElementProviderKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC37AdsEmbedded_EmbeddedAdPresentationKit28LeavebehindAdElementProvider"

    func load() {
        adlog("LeavebehindAdElementProvider.load")
    }
}

// HTML-backed brand-ad creative. NSObject-based with an internal cast:
// ElementUI classes have proven non-UIView on some 9.1.x builds.
class HtmlAdElementUIKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdViewGroup
    static let targetName =
        "_TtC22AdsPlatform_ElementKit15HtmlAdElementUI"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("HtmlAdElementUI")
            view.removeFromSuperview()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// Rewarded / on-demand and app-open ad module (AdsStandalone_RewardedAdImpl).
// This module had no service-level coverage at all. 9.1.90 added
// OnDemandAdEventLoggerService to it and the fetch controller / interrupting
// video launcher are the pieces that actually play the video.
// ─────────────────────────────────────────────────────────────────────
class RewardedAdFetchControllerServiceKill: ClassHook<NSObject> {
    typealias Group = AdsStandaloneServiceGroup
    static let targetName =
        "_TtC28AdsStandalone_RewardedAdImpl32RewardedAdFetchControllerService"

    func load() {
        adlog("RewardedAdFetchControllerService.load")
    }
}

class OnDemandAdEventLoggerServiceKill: ClassHook<NSObject> {
    typealias Group = AdsStandaloneServiceGroup
    static let targetName =
        "_TtC28AdsStandalone_RewardedAdImpl28OnDemandAdEventLoggerService"

    func load() {
        adlog("OnDemandAdEventLoggerService.load")
    }
}

class InterruptingVideoAdLauncherImplKill: ClassHook<NSObject> {
    typealias Group = AdsStandaloneServiceGroup
    static let targetName =
        "_TtC28AdsStandalone_RewardedAdImpl31InterruptingVideoAdLauncherImpl"

    func load() {
        adlog("InterruptingVideoAdLauncherImpl.load")
    }
}

// ─────────────────────────────────────────────────────────────────────
// Native ad element factory (NativeAds_ElementImpl) — separate from
// AdsPlatform_AdsImpl, so the AdsServiceImpl kill never reached it.
// ─────────────────────────────────────────────────────────────────────
class NativeAdsElementServiceImplKill: ClassHook<NSObject> {
    typealias Group = NativeAdsServiceGroup
    static let targetName =
        "_TtC21NativeAds_ElementImpl27NativeAdsElementServiceImpl"

    func load() {
        adlog("NativeAdsElementServiceImpl.load")
    }
}

// DSA ad transparency is two surfaces: the view (below) and the service that
// provisions it. Blocking both stops the notice being built at all.
class DSAServiceImplKill: ClassHook<NSObject> {
    typealias Group = NativeAdsServiceGroup
    static let targetName =
        "_TtC19AdsPlatform_DSAImpl14DSAServiceImpl"

    func load() {
        adlog("DSAServiceImpl.load")
    }
}

// ─────────────────────────────────────────────────────────────────────
// Ad-topic survey surface (AdsPlatform_ElementKit) — NEW in 9.1.90. This is a
// survey Spotify shows about ad topics; it is ad-only, so it is hidden rather
// than starved. Same hide-on-attach pattern as the other element-UIs.
// ─────────────────────────────────────────────────────────────────────
class AdTopicSurveyElementUIKill: ClassHook<NSObject> {
    typealias Group = AdsSurveyViewGroup
    static let targetName =
        "_TtC22AdsPlatform_ElementKit22AdTopicSurveyElementUI"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("AdTopicSurveyElementUI (ad survey)")
            view.removeFromSuperview()
        }
    }
}

// DSA ad-transparency overlay (AdsPlatform_DSAImpl) — ad-only surface.
class DSAMainViewKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdViewGroup
    static let targetName =
        "_TtC19AdsPlatform_DSAImpl11DSAMainView"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("DSAMainView")
            view.removeFromSuperview()
        }
    }
}

func activateEeveeAdBlockerExtended() {
    let loadSelector = Selector(("load"))
    let initSelector = Selector(("init"))

    let loadTargets: [(String, String, () -> Void)] = [
        (AdsServiceImplKill.targetName, "AdsServiceImpl", { activateOnce(AdsServiceImplGroup.self) { AdsServiceImplGroup() } }),
        (InStreamAdsServiceKill.targetName, "InStreamAdsService", { activateOnce(InStreamAdsServiceGroup.self) { InStreamAdsServiceGroup() } }),
        (EmbeddedNPVServiceImplKill.targetName, "EmbeddedNPVServiceImpl", { activateOnce(EmbeddedNPVServiceGroup.self) { EmbeddedNPVServiceGroup() } }),
        (LeavebehindAdsBaseServiceKill.targetName, "LeavebehindAdsBaseService", { activateOnce(LeavebehindAdsBaseServiceGroup.self) { LeavebehindAdsBaseServiceGroup() } }),
        (LeavebehindAdsBaseInternalServiceKill.targetName, "LeavebehindAdsBaseInternalService", { activateOnce(LeavebehindAdsBaseInternalServiceGroup.self) { LeavebehindAdsBaseInternalServiceGroup() } }),
        (SponsoredContextServiceKill.targetName, "AdsSponsoredContextServiceImpl", { activateOnce(SponsoredContextServiceGroup.self) { SponsoredContextServiceGroup() } }),
        (SponsoredContextNPBAttachmentServiceKill.targetName, "AdsSponsoredContextNPBAttachmentServiceImpl", { activateOnce(SponsoredContextNPBAttachmentServiceGroup.self) { SponsoredContextNPBAttachmentServiceGroup() } }),
        (SponsoredPlaylistHeaderServiceKill.targetName, "AdsSponsoredPlaylistHeaderServiceImpl", { activateOnce(SponsoredPlaylistHeaderServiceGroup.self) { SponsoredPlaylistHeaderServiceGroup() } }),
        (NativeAdsLoggerServiceImplKill.targetName, "NativeAdsLoggerServiceImpl", { activateOnce(NativeAdsLoggerServiceGroup.self) { NativeAdsLoggerServiceGroup() } }),
        (EmbeddedAdAdapterElementProviderKill.targetName, "EmbeddedAdAdapterElementProvider", { activateOnce(ScrollFeedAdControllerGroup.self) { ScrollFeedAdControllerGroup() } }),
        (PlaylistAdControllerV2Kill.targetName, "PlaylistAdControllerV2", { activateOnce(ScrollFeedAdControllerGroup.self) { ScrollFeedAdControllerGroup() } }),
        (PlaylistAdControllerImplKill.targetName, "PlaylistAdControllerImpl", { activateOnce(ScrollFeedAdControllerGroup.self) { ScrollFeedAdControllerGroup() } }),
        (LeavebehindAdElementProviderKill.targetName, "LeavebehindAdElementProvider", { activateOnce(ScrollFeedAdControllerGroup.self) { ScrollFeedAdControllerGroup() } }),
        (RewardedAdFetchControllerServiceKill.targetName, "RewardedAdFetchControllerService", { activateOnce(AdsStandaloneServiceGroup.self) { AdsStandaloneServiceGroup() } }),
        (OnDemandAdEventLoggerServiceKill.targetName, "OnDemandAdEventLoggerService", { activateOnce(AdsStandaloneServiceGroup.self) { AdsStandaloneServiceGroup() } }),
        (InterruptingVideoAdLauncherImplKill.targetName, "InterruptingVideoAdLauncherImpl", { activateOnce(AdsStandaloneServiceGroup.self) { AdsStandaloneServiceGroup() } }),
        (NativeAdsElementServiceImplKill.targetName, "NativeAdsElementServiceImpl", { activateOnce(NativeAdsServiceGroup.self) { NativeAdsServiceGroup() } }),
        (DSAServiceImplKill.targetName, "DSAServiceImpl", { activateOnce(NativeAdsServiceGroup.self) { NativeAdsServiceGroup() } }),
    ]

    var activated = 0
    for (className, label, activate) in loadTargets {
        guard let cls = findTweakClass(className) else {
            ablog("\(label)/load unavailable: class not registered yet")
            continue
        }
        guard class_getInstanceMethod(cls, loadSelector) != nil else {
            ablog("\(label)/load unavailable: no load selector on \(NSStringFromClass(cls))")
            continue
        }
        activate()
        activated += 1
        ablog("\(label) hook activated")
    }

    if let cls = findTweakClass(SponsoredCtxAttachmentProbe.targetName),
       class_getInstanceMethod(cls, initSelector) != nil {
        activateOnce(SponsoredCtxAttachmentGroup.self) { SponsoredCtxAttachmentGroup() }
        activated += 1
        ablog("SponsoredCtxAttachment hook activated")
    } else {
        ablog("SponsoredCtxAttachment/init unavailable; skipping")
    }

    let viewSelector = Selector(("didMoveToSuperview"))
    if let cls = findTweakClass(SponsoredPlaylistHeaderViewKill.targetName) as? UIView.Type,
       class_getInstanceMethod(cls, viewSelector) != nil {
        activateOnce(SponsoredPlaylistHeaderViewGroup.self) { SponsoredPlaylistHeaderViewGroup() }
        activated += 1
        ablog("SponsoredPlaylistHeader view fallback activated")
    } else {
        ablog("SponsoredPlaylistHeader view unavailable; skipping")
    }

    // Scroll-feed ad card (9.1.8x scrollsita): view-level hide + service-level
    // starvation. Both runtime-gated so older builds degrade gracefully.
    // Orion rejects this class as non-UIView (9.1.84), so the NSObject hook
    // below attaches only if a view-compatible method actually exists.
    if let cls = findTweakClass(EmbeddedAdAdapterElementUIKill.targetName),
       class_getInstanceMethod(cls, viewSelector) != nil {
        activateOnce(ScrollFeedAdViewGroup.self) { ScrollFeedAdViewGroup() }
        activated += 1
        ablog("EmbeddedAdAdapterElementUI (scroll-feed ad) activated")
    } else {
        ablog("EmbeddedAdAdapterElementUI unavailable; skipping")
    }

    if let cls = findTweakClass(EmbeddedCTAElementsServiceImplKill.targetName),
       class_getInstanceMethod(cls, loadSelector) != nil {
        activateOnce(ScrollFeedAdServiceGroup.self) { ScrollFeedAdServiceGroup() }
        activated += 1
        ablog("EmbeddedCTAElementsServiceImpl activated")
    } else {
        ablog("EmbeddedCTAElementsServiceImpl unavailable; skipping")
    }

    if let cls = findTweakClass(EmbeddedAdControllerServiceImplKill.targetName),
       class_getInstanceMethod(cls, loadSelector) != nil {
        activateOnce(ScrollFeedAdControllerGroup.self) { ScrollFeedAdControllerGroup() }
        activated += 1
        ablog("EmbeddedAdControllerServiceImpl activated")
    } else {
        ablog("EmbeddedAdControllerServiceImpl unavailable; skipping")
    }

    if let cls = findTweakClass(HtmlAdElementUIKill.targetName),
       class_getInstanceMethod(cls, viewSelector) != nil {
        activateOnce(ScrollFeedAdViewGroup.self) { ScrollFeedAdViewGroup() }
        activated += 1
        ablog("HtmlAdElementUI fallback activated")
    } else {
        ablog("HtmlAdElementUI unavailable; skipping")
    }

    if let cls = findTweakClass(DSAMainViewKill.targetName),
       class_getInstanceMethod(cls, viewSelector) != nil {
        activateOnce(ScrollFeedAdViewGroup.self) { ScrollFeedAdViewGroup() }
        activated += 1
        ablog("DSAMainView fallback activated")
    } else {
        ablog("DSAMainView unavailable; skipping")
    }

    // Ad-topic survey element (NEW in 9.1.90). Runtime-gated so older builds
    // simply skip it.
    if let cls = findTweakClass(AdTopicSurveyElementUIKill.targetName),
       class_getInstanceMethod(cls, viewSelector) != nil {
        activateOnce(AdsSurveyViewGroup.self) { AdsSurveyViewGroup() }
        activated += 1
        ablog("AdTopicSurveyElementUI (ad survey) activated")
    } else {
        ablog("AdTopicSurveyElementUI unavailable; skipping")
    }

    ablog("activated \(activated)/\(loadTargets.count + 8) compatible extended hooks")
}
