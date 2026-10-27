import Foundation

/// The status map under the page title: Madrid's districts with one dot per park, in its alert colour.
/// Each dot links to the park's card in "Ahora": Safari shows no SVG tooltips, and touch screens have no hover.
enum ParkMap {
    /// Where a park sits, and where its label goes so it stays clear of its neighbours
    private struct Spot {
        let label: String
        let lat: Double
        let lon: Double
        let dx: Double
        let dy: Double
        let anchor: String
    }

    // Positions from OpenStreetMap, Fuente del Berro and Rosaleda placed by hand. Lineal del Manzanares runs for
    // kilometres along the river: its dot marks the middle. A park missing here simply gets no dot.
    private static let spots: [String: Spot] = [
        "Jardines del Buen Retiro": Spot(label: "Retiro", lat: 40.4149, lon: -3.6833, dx: 0, dy: 26, anchor: "middle"),
        "Jardín del Capricho de la Alameda de Osuna":
            Spot(label: "El Capricho", lat: 40.4534, lon: -3.5942, dx: 16, dy: 7, anchor: "start"),
        "Parque Juan Carlos I":
            Spot(label: "Juan Carlos I", lat: 40.4608, lon: -3.6058, dx: 0, dy: -18, anchor: "middle"),
        "Parque Juan Pablo II": Spot(label: "Juan Pablo II", lat: 40.4550, lon: -3.6264, dx: -16, dy: 0, anchor: "end"),
        "Parque Lineal del Manzanares":
            Spot(label: "Lineal del Manzanares", lat: 40.3493, lon: -3.6706, dx: 16, dy: 7, anchor: "start"),
        "Parque Quinta Fuente del Berro":
            Spot(label: "Fuente del Berro", lat: 40.4237, lon: -3.6650, dx: 16, dy: 7, anchor: "start"),
        "Parque Quinta de Torre Arias":
            Spot(label: "Torre Arias", lat: 40.4456, lon: -3.6203, dx: 16, dy: 12, anchor: "start"),
        "Parque Quinta de los Molinos":
            Spot(label: "Quinta de los Molinos", lat: 40.4414, lon: -3.6273, dx: -16, dy: 16, anchor: "end"),
        "Rosaleda del Parque del Oeste":
            Spot(label: "Rosaleda", lat: 40.4262, lon: -3.7212, dx: -16, dy: 7, anchor: "end"),
    ]

    // The view: about 1.5:1, the widest that keeps every park (Lineal del Manzanares lies far south). Small units,
    // so labels still read at about 11 px on a phone.
    private static let width = 600.0
    private static let height = 401.0
    private static let minLon = -3.80
    private static let maxLon = -3.515
    private static let maxLat = 40.478
    private static let cosLat = cos(40.42 * Double.pi / 180)
    private static let scale = width / ((maxLon - minLon) * cosLat)

    /// - Parameters:
    ///   - codes: each park's alert code, by API name
    ///   - cardIDs: the id of each park's card in "Ahora", by API name; parks without one get no link
    static func render(codes: [String: Int], cardIDs: [String: String]) -> String {
        // Most severe drawn last, so it sits on top where dots touch
        let dots = codes
            .compactMap { name, code in spots[name].map { (name: name, code: code, spot: $0) } }
            .sorted { ($0.code, $0.name) < ($1.code, $1.name) }
            .map { park -> String in
                let x = (park.spot.lon - minLon) * cosLat * scale
                let y = (maxLat - park.spot.lat) * scale
                let status = "\(park.spot.label): \(WebsiteGenerator.levelName(park.code))"
                let dot = """
                <title>\(status)</title><circle class="\(WebsiteGenerator.levelClass(park.code))" \
                cx="\(Int(x))" cy="\(Int(y))" r="11"/><text x="\(Int(x + park.spot.dx))" y="\(Int(y + park.spot.dy))" \
                text-anchor="\(park.spot.anchor)">\(park.spot.label)</text>
                """
                guard let id = cardIDs[park.name] else { return "<g>\(dot)</g>" }
                return "<a href=\"#\(id)\" aria-label=\"\(status)\">\(dot)</a>"
            }
            .joined(separator: "\n")

        return """
        <figure class="map-figure">
        <svg class="map" viewBox="0 0 \(Int(width)) \(Int(height))" role="group" aria-label="Mapa de los parques">
        <rect class="outside" width="100%" height="100%"/><path class="districts" d="\(districts)"/>
        \(dots)
        </svg>
        <figcaption>Localizaciones en el mapa de Madrid</figcaption>
        </figure>
        """
    }

    /// Madrid's 21 districts, projected into the view above. From the city's open data (sigma.madrid.es,
    /// CARTOGRAFIA/LIMITES_ADMINISTRATIVOS, layer 3 "DISTRITOS"), simplified to 0.0015° and rounded to whole units.
    private static let districts = """
    M203 316L166 313L158 395L180 415L184 427L219 431L225 437L254 419L274 423L287 412L300 412L286 372L275 367\
    L274 356L249 323L227 314L203 316ZM406 252L375 241L369 265L311 282L306 298L281 318L249 323L274 356L275 367\
    L286 372L300 412L317 400L357 435L379 439L397 453L425 459L467 454L471 451L455 449L452 441L458 419L479 399\
    L517 335L424 287L420 280L426 272L418 257L406 252ZM170 216L157 201L116 249L99 261L86 261L93 275L80 286\
    L80 307L60 327L89 334L167 311L173 256L201 229L170 216ZM246 313L248 299L236 287L233 265L201 229L173 256\
    L166 313L227 314L249 323L246 313ZM257 324L285 315L306 298L311 282L369 265L375 241L331 228L305 202L284 198\
    L275 222L247 258L232 265L236 287L248 299L249 323L257 324ZM163 184L163 168L122 190L103 193L75 217L51 215\
    L39 232L22 237L24 232L-9 238L-43 225L-72 226L-22 316L-15 308L26 330L41 321L60 327L80 307L80 286L93 275\
    L86 261L99 261L116 249L148 209L157 201L163 203L163 184ZM202 201L175 192L175 177L162 177L165 213L201 229\
    L232 265L246 259L266 231L255 213L228 192L202 201ZM471 179L464 168L473 145L468 144L445 192L399 179L398 166\
    L392 169L379 178L358 236L416 254L426 272L420 280L423 286L494 326L551 247L561 239L570 245L589 238L593 210\
    L591 191L585 178L566 160L568 175L557 176L548 187L471 179ZM331 176L297 164L284 198L303 200L329 227L358 236\
    L378 179L331 176ZM286 192L297 164L255 156L225 162L228 192L255 213L266 231L286 192ZM225 196L224 171L231 146\
    L176 131L188 151L168 160L162 177L175 177L175 192L187 197L205 202L225 196ZM375 173L341 111L346 109L339 95\
    L323 84L289 38L283 3L296 -14L266 -17L266 11L284 50L296 99L293 129L297 164L328 175L378 179L375 173ZM435 77\
    L320 79L339 95L346 109L341 111L378 179L398 166L399 179L445 192L468 144L471 134L465 123L473 121L472 114\
    L487 116L566 86L435 77ZM-2 24L-77 -4L-81 28L-72 38L-61 32L-9 41L15 66L24 89L21 98L32 93L61 94L61 134\
    L44 148L39 167L53 215L75 217L90 200L122 190L188 151L173 124L169 92L193 85L183 69L193 43L181 24L119 10\
    L106 12L105 22L102 -1L90 -5L88 15L40 9L-2 24ZM296 110L293 92L258 112L230 111L235 124L225 162L255 156\
    L297 164L293 129L296 110ZM229 88L172 87L169 92L173 124L176 131L231 146L235 124L228 101L229 88ZM266 -12\
    L266 -17L242 -12L233 33L230 111L258 112L293 92L284 50L266 11L266 -12ZM216 10L187 19L183 26L193 43L183 69\
    L193 85L229 88L238 11L216 10ZM501 -92L480 -95L435 -65L417 -65L417 -19L388 -19L383 -12L367 -12L371 17\
    L370 26L362 26L377 49L410 70L405 78L566 85L559 71L576 62L569 48L579 25L560 17L554 -23L545 -29L544 -45\
    L521 -58L515 -70L517 -92L501 -92ZM311 -92L300 -93L297 -70L267 -29L266 -17L296 -14L283 3L291 40L320 79\
    L405 78L412 72L377 49L362 26L370 26L371 17L367 -12L383 -12L388 -19L417 -19L417 -65L389 -91L351 -82L327 -83\
    L311 -92ZM327 -443L304 -457L291 -447L277 -417L280 -392L237 -356L218 -309L199 -290L167 -288L132 -299\
    L125 -311L46 -342L-7 -334L-1 -354L-20 -365L-27 -360L-13 -337L-30 -325L-58 -323L-79 -314L-91 -316L-116 -304\
    L-142 -316L-160 -310L-176 -297L-176 -280L-187 -257L-176 -237L-179 -229L-155 -220L-133 -157L-113 -128\
    L-115 -120L-108 -110L-114 -94L-111 -88L-78 -77L-83 -59L-72 -45L-70 -27L-77 -4L-0 24L40 9L88 15L90 -5\
    L102 -1L105 22L104 14L111 10L152 14L183 26L186 19L210 9L238 11L242 -12L266 -17L270 -37L297 -71L300 -93\
    L289 -116L282 -119L282 -129L259 -136L275 -156L249 -199L233 -256L230 -252L207 -278L228 -283L287 -316\
    L303 -307L315 -275L368 -264L408 -296L417 -312L410 -328L387 -342L383 -369L373 -381L361 -386L359 -413\
    L344 -439L327 -443Z
    """
}
