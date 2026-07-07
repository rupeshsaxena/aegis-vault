struct IdentityValidator: DomainValidator {
    func validate(_ aggregate: IdentityAggregate) throws {
        try aggregate.validateInvariants()
    }
}
