import Foundation

/// A culture's decorative vocabulary, used on the runner's tunic hem and trim,
/// and as the body pattern on that realm's guardian. Drawn procedurally in Game/MotifPainter.
enum Motif: String, Codable, CaseIterable {
    case meander        // Greek key
    case lotus          // Egyptian lotus band
    case knotwork       // Norse interlace
    case seigaiha       // Japanese overlapping waves
    case stepFret       // Mesoamerican xicalcoliuhqui
    case triskele       // Celtic spirals
    case paisley        // South Asian buta
    case rosette        // Mesopotamian eight-petal rosette
    case adire          // Yoruba indigo resist circles
    case koru           // Māori unfurling fern
    case cloud          // Chinese xiangyun
    case mayaStep       // Maya stepped glyph band
    case crossStitch    // Slavic embroidered rushnyk
    case beadTriangles  // Zulu beadwork
    case furTrim        // Inuit parka trim
    case girih          // Persian star-and-polygon
    case kapa           // Hawaiian kapa triangles
    case tocapu         // Inca checkered squares
    case kantele        // Finnish birch-bark / ryijy diamonds
    case kente          // Akan woven strips
    case ulzii          // Mongolian endless knot
    case hittiteSpiral  // Anatolian running spiral
    case rongorongo     // Rapa Nui glyph line
    case zemiSpiral     // Taíno spiral
    case etruscanWave   // running wave (Vitruvian scroll)
    case dogonChevron   // Dogon chevron weave
    case ayus           // Ainu thorn-curl
    case nanduti        // Guaraní ñandutí spiderweb lace
    case okir           // Visayan/Mindanao curling vine
    case rockDots       // San rock-art dot rows
}

/// What makes each realm's guardian look like itself. Shared rigs (giant, serpent…) animate the body;
/// these fields change its anatomy and finish, and `signature` adds the one detail no other guardian has.
struct GuardianDesign: Codable, Hashable {
    enum Eyes: String, Codable { case pair, single, many, slits, hollow, mirror }
    enum Horns: String, Codable { case none, ram, bull, antlers, spikes, single }
    enum Headgear: String, Codable { case none, crown, helmet, feathers, hood, mane, crest }
    enum Tail: String, Codable { case none, plain, serpent, fish, flame, plume, spiked }
    enum Aura: String, Codable { case none, flames, frost, sparks, smoke, water, dust, petals, stars, lightning, leaves }
    /// One per guardian. Each is drawn by its own function in Game/GuardianSignatures.swift.
    enum Signature: String, Codable, CaseIterable {
        case ichorVein, sunSwallower, gleipnir, mossBacks, jointMouths, evilEye, hoardedWaters
        case coiledFace, cowrieCrest, pauaEyes, firecrackers, jewelTeeth, needleEgg, horseMane
        case amautik, stoneClub, peleHair, featheredSerpent, scytheTalons, ironHooks, manyHeads
        case stolenHeart, firstEgg, zemiArms, goatAndSerpent, dustStar, iceFangs, sevenDogs
        case moonInMouth, starMaw
    }

    var heads: Int = 1
    var eyes: Eyes = .pair
    var horns: Horns = .none
    var headgear: Headgear = .none
    var wings: Bool = false
    var tail: Tail = .plain
    var aura: Aura = .none
    var signature: Signature

    init(heads: Int = 1, eyes: Eyes = .pair, horns: Horns = .none, headgear: Headgear = .none,
         wings: Bool = false, tail: Tail = .plain, aura: Aura = .none, signature: Signature) {
        self.heads = heads; self.eyes = eyes; self.horns = horns; self.headgear = headgear
        self.wings = wings; self.tail = tail; self.aura = aura; self.signature = signature
    }

    // Every field but `signature` is optional in JSON, so content stays short.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heads = try c.decodeIfPresent(Int.self, forKey: .heads) ?? 1
        eyes = try c.decodeIfPresent(Eyes.self, forKey: .eyes) ?? .pair
        horns = try c.decodeIfPresent(Horns.self, forKey: .horns) ?? .none
        headgear = try c.decodeIfPresent(Headgear.self, forKey: .headgear) ?? .none
        wings = try c.decodeIfPresent(Bool.self, forKey: .wings) ?? false
        tail = try c.decodeIfPresent(Tail.self, forKey: .tail) ?? .plain
        aura = try c.decodeIfPresent(Aura.self, forKey: .aura) ?? .none
        signature = try c.decode(Signature.self, forKey: .signature)
    }
}
