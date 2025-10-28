// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Project - Skill Verification NFT Platform
 * @dev Non-transferable NFT platform for cryptographically verified credentials
 */
contract Project is ERC721, Ownable {
    
    uint256 private _tokenIdCounter;
    
    struct Credential {
        string skillName;
        string issuerName;
        address issuerAddress;
        uint256 issueDate;
        string metadataURI;
        bool isValid;
    }
    
    mapping(uint256 => Credential) public credentials;
    mapping(address => bool) public authorizedIssuers;
    mapping(address => mapping(address => mapping(string => bool))) public hasCredential;
    
    event IssuerAuthorized(address indexed issuer);
    event CredentialIssued(uint256 indexed tokenId, address indexed recipient, string skillName);
    event CredentialRevoked(uint256 indexed tokenId);
    
    constructor() ERC721("SkillVerify Credential", "SKILL") Ownable(msg.sender) {}
    
    /**
     * @dev CORE FUNCTION 1: Issue a credential NFT to verify skills
     * @param recipient Address receiving the credential
     * @param skillName Name of the skill/certification
     * @param issuerName Name of the issuing organization
     * @param metadataURI Link to detailed credential information
     */
    function issueCredential(
        address recipient,
        string memory skillName,
        string memory issuerName,
        string memory metadataURI
    ) external returns (uint256) {
        require(authorizedIssuers[msg.sender], "Not an authorized issuer");
        require(recipient != address(0), "Invalid recipient address");
        require(!hasCredential[recipient][msg.sender][skillName], "Credential already exists");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(recipient, tokenId);
        
        credentials[tokenId] = Credential({
            skillName: skillName,
            issuerName: issuerName,
            issuerAddress: msg.sender,
            issueDate: block.timestamp,
            metadataURI: metadataURI,
            isValid: true
        });
        
        hasCredential[recipient][msg.sender][skillName] = true;
        
        emit CredentialIssued(tokenId, recipient, skillName);
        
        return tokenId;
    }
    
    /**
     * @dev CORE FUNCTION 2: Verify a credential's authenticity
     * @param tokenId Token ID to verify
     * @return isValid Whether the credential is currently valid
     * @return holder Address of the credential holder
     * @return skillName Name of the verified skill
     * @return issuerName Organization that issued the credential
     */
    function verifyCredential(uint256 tokenId) external view returns (
        bool isValid,
        address holder,
        string memory skillName,
        string memory issuerName
    ) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        Credential memory cred = credentials[tokenId];
        
        return (
            cred.isValid,
            ownerOf(tokenId),
            cred.skillName,
            cred.issuerName
        );
    }
    
    /**
     * @dev CORE FUNCTION 3: Authorize trusted organizations to issue credentials
     * @param issuer Address of the organization (employer, school, bootcamp)
     */
    function authorizeIssuer(address issuer) external onlyOwner {
        require(issuer != address(0), "Invalid issuer address");
        require(!authorizedIssuers[issuer], "Already authorized");
        
        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }
    
    /**
     * @dev Revoke a credential (issuer only)
     */
    function revokeCredential(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(credentials[tokenId].issuerAddress == msg.sender, "Only issuer can revoke");
        require(credentials[tokenId].isValid, "Already revoked");
        
        credentials[tokenId].isValid = false;
        
        address holder = ownerOf(tokenId);
        hasCredential[holder][msg.sender][credentials[tokenId].skillName] = false;
        
        emit CredentialRevoked(tokenId);
    }
    
    /**
     * @dev Make NFTs non-transferable (soulbound)
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        if (from != address(0) && to != address(0)) {
            revert("Credentials cannot be transferred");
        }
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev Get all credentials for an address
     */
    function getHolderCredentials(address holder) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(holder);
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 index = 0;
        
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_ownerOf(i) == holder) {
                tokenIds[index] = i;
                index++;
            }
        }
        
        return tokenIds;
    }
}
