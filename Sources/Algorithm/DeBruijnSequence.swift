public func deBruijnSequence<Alphabets: RandomAccessCollection>(of alphabets:Alphabets, length: Int) -> [Alphabets.Element] {
    typealias Alphabet = Alphabets.Element
    
    let alphabetCount = alphabets.count
    let cycleCount = repeatElement(alphabetCount, count: length - 1).reduce(1, *)
    let debruijnLength = cycleCount * alphabetCount

    var used = Array(repeating: false, count: debruijnLength)
    var result: [Alphabet] = []
    result.reserveCapacity(debruijnLength)
    
    for index in 0..<debruijnLength {
        var current = index
        while !used[current] {
            used[current] = true

            let elementIndex = current / cycleCount
            current = (current % cycleCount) * alphabetCount + elementIndex
            result.append(alphabets[alphabets.index(alphabets.startIndex, offsetBy: elementIndex)])
        }
        assert(current == index)
    }
    
    assert(result.count == debruijnLength)
    return result
}
