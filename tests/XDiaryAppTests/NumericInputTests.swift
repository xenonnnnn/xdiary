import Testing
@testable import xdiary

struct NumericInputTests {
    @Test("最大值不在步长格点时使用最后一个合法值")
    func usesLastValidStep() {
        #expect(normalizedNumber(8, min: 0, max: 8, step: 3) == 6)
    }

    @Test("支持非零起点与小数步长")
    func respectsOriginAndDecimalStep() {
        #expect(normalizedNumber(1.44, min: 0.1, max: 2, step: 0.2) == 1.5)
    }

    @Test("没有步长时只按范围限制")
    func clampsWithoutStep() {
        #expect(normalizedNumber(25, min: 10, max: 100, step: nil) == 25)
        #expect(normalizedNumber(2, min: 10, max: 100, step: nil) == 10)
    }
}
