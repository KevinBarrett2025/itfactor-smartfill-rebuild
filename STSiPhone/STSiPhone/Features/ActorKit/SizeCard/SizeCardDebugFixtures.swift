#if DEBUG
import Foundation

enum SizeCardDebugFixtures {
    static var worstCaseProfile: ActorProfile {
        var profile = ActorProfile()
        profile.name = "Alexandra Maximilian-Cruz"
        profile.email = "alexandra.maximilian.cruz@verylongtalentagency.com"
        profile.phone = "+1 (212) 555-0199"
        profile.sagStatus = .member
        profile.sagNumber = "SAG-1029384"
        profile.ageRange = "13-17"
        profile.sex = .undisclosed
        profile.primaryLocation = "Los Angeles, CA"
        profile.localHireMarket = "New York, NY (Local Hire)"
        profile.height = "6' 2\""
        profile.weight = "215 lb"
        profile.hairColor = "Dark Brown with Auburn Highlights"
        profile.eyeColor = "Green/Hazel"
        profile.shirtSize = "Large (US 42)"
        profile.pantSize = "34x32 Long"
        profile.shoeSize = "11.5 Wide"

        var measurements = ActorMeasurements()
        measurements.waist = "34 in / 86 cm"
        measurements.inseam = "32 in / 81 cm"
        measurements.glove = "L / 9.5"
        measurements.hat = "7 5/8"
        measurements.chest = "42 in / 107 cm"
        measurements.neck = "16.5 in"
        measurements.sleeve = "35 in"
        measurements.coat = "42R"
        measurements.mensTShirt = "Large"
        measurements.mensShoe = "11.5"
        measurements.mensShoeWidth = "EE / Extra Wide"
        measurements.dress = "US 10 / EU 40"
        measurements.bust = "36 in"
        measurements.underbust = "31 in"
        measurements.cup = "D"
        measurements.hip = "40 in"
        measurements.womensTShirt = "Medium"
        measurements.womensPants = "10 Long"
        measurements.womensShoe = "9.5"
        measurements.womensShoeWidth = "W / Wide"
        measurements.boys = "14"
        measurements.girls = "14"
        measurements.toddlers = "3T"
        measurements.infants = "12M"
        measurements.kidsShoe = "4Y"
        measurements.kidsSpecial = "Slim / Adjustable"
        profile.measurements = measurements

        profile.socialLinks = SocialLinks(
            instagram: "alexandra_maximilian_cruz_official",
            facebook: "alexandra.maximilian.cruz.actor",
            tiktok: "@alexandraMaxCruz",
            imdb: "nm1234567"
        )
        return profile
    }

    static var worstCaseReps: [RepInfo] {
        [
            RepInfo(
                category: "Film/TV Agent",
                name: "Jordan Callahan",
                email: "jordan.callahan@northstar-talent.com",
                phone: "+1 (310) 555-0118"
            ),
            RepInfo(
                category: "Commercial Agent",
                name: "Maya Rodriguez",
                email: "maya.rodriguez@brightlineagency.com",
                phone: "+1 (646) 555-0142"
            ),
            RepInfo(
                category: "Manager",
                name: "Alex Kim",
                email: "alex.kim@atlasmgmt.co",
                phone: "+1 (212) 555-0177"
            ),
            RepInfo(
                category: "Publicist",
                name: "Priya Desai",
                email: "priya@pinnaclepublicity.com",
                phone: "+1 (818) 555-0191"
            )
        ]
    }

    static var worstCaseConfig: SizeCardConfig {
        var config = SizeCardConfig.default
        config.columnStyle = .auto
        config.visibility.showUnion = true
        config.visibility.showPrimaryLocation = true
        config.visibility.showLocalHire = true
        config.visibility.showEmail = true
        config.visibility.showPhone = true
        config.visibility.showWardrobe = true
        config.visibility.showReps = true
        config.visibility.showLinks = true
        config.visibility.showInstagram = true
        config.visibility.showFacebook = true
        config.visibility.showTiktok = true
        config.visibility.showImdb = true
        config.visibility.showWatermarkQR = true
        config.hiddenMeasurementFields = []
        config.customFields = [
            SizeCardCustomField(
                label: "Passport / Visa Status",
                value: "O-1, EU dual citizen",
                isVisible: true,
                order: 0
            ),
            SizeCardCustomField(
                label: "Special Skills",
                value: "Stage combat, fluent Spanish & ASL",
                isVisible: true,
                order: 1
            )
        ]
        config.template.templateID = SizeCardTemplate.compact.rawValue
        config.template.aspect = .half
        return config
    }
}
#endif
