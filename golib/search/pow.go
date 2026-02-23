package search

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"runtime"
	"strconv"
	"sync"
	"time"
)

// Challenge represents the PoW challenge structure
type Challenge struct {
	Challenges []string `json:"challenges"`
	Difficulty int      `json:"difficulty"`
	Count      int      `json:"count"`
	Hint       string   `json:"hint"`
}

// ChallengeResponse represents the API response for challenge request
type ChallengeResponse struct {
	Success bool      `json:"success"`
	Data    Challenge `json:"data"`
	Error   string    `json:"error,omitempty"`
}

// Solution represents the solution for a single challenge
type Solution struct {
	Challenge string `json:"challenge"`
	Signature string `json:"signature"`
	Nonce     string `json:"nonce"`
}

// VerifyRequest represents the verification request
type VerifyRequest struct {
	PublicKey string     `json:"publicKey"`
	Solutions []Solution `json:"solutions"`
}

// VerifyResponse represents the verification response
type VerifyResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    struct {
		PublicKey  string `json:"publicKey"`
		VerifiedAt int64  `json:"verifiedAt"`
	} `json:"data"`
	Error string `json:"error,omitempty"`
}

// PowSolution represents the PoW solution for data submission
type PowSolution struct {
	PublicKey string     `json:"publicKey"`
	Solutions []Solution `json:"solutions"`
}

// SubmitRequest represents the data submission request
type SubmitRequest struct {
	PublicKey   string      `json:"publicKey"`
	PowSolution PowSolution `json:"powSolution"`
	NknAddress  string      `json:"nknAddress"`
	CustomId    string      `json:"customId,omitempty"`
	Nickname    string      `json:"nickname,omitempty"`
	PhoneNumber string      `json:"phoneNumber,omitempty"`
}

// SubmitResponse represents the submission response
type SubmitResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Error   string `json:"error,omitempty"`
}

// SearchClient is the search client for NKN search server
type SearchClient struct {
	apiBase       *url.URL
	privateKey    []byte
	publicKey     []byte
	walletAddr    string
	isVerified    bool
	verifiedUntil time.Time
	mu            sync.RWMutex
	httpClient    *http.Client
}

// init initializes the search package
// Sets GOMAXPROCS to enable parallel execution on multi-core devices
func init() {
	// Enable parallel execution by setting GOMAXPROCS to CPU count
	numCPU := runtime.NumCPU()
	runtime.GOMAXPROCS(numCPU)
	log.Printf("Search package initialized: GOMAXPROCS set to %d (CPU cores: %d)",
		runtime.GOMAXPROCS(0), numCPU)
}

// QueryResult represents the query result
type QueryResult struct {
	Success bool   `json:"success"`
	Data    string `json:"data"` // JSON formatted result
	Error   string `json:"error,omitempty"`
}

// sign signs a message (hex string)
func (c *SearchClient) sign(messageHex string) (string, error) {
	// NKN SDK expects message to be a hex string, need to decode first
	messageBytes, err := hex.DecodeString(messageHex)
	if err != nil {
		return "", fmt.Errorf("failed to decode hex message: %w", err)
	}

	// Sign using ed25519
	signature := ed25519.Sign(c.privateKey, messageBytes)

	// Return hex encoded signature
	return hex.EncodeToString(signature), nil
}

// GetPublicKeyHex returns the public key in hex format
func (c *SearchClient) GetPublicKeyHex() string {
	return hex.EncodeToString(c.publicKey)
}

// GetAddress returns the wallet address
func (c *SearchClient) GetAddress() string {
	return c.walletAddr
}

// IsVerified checks if the client is verified
func (c *SearchClient) IsVerified() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.isVerified && time.Now().Before(c.verifiedUntil)
}

// solvePoW calculates PoW - finds a nonce that satisfies the difficulty
// Single-threaded optimized version for maximum performance on mobile devices
func solvePoW(signature string, difficulty int) (string, time.Duration) {
	startTime := time.Now()

	log.Printf("Starting single-threaded PoW calculation (difficulty: %d)", difficulty)

	// Pre-convert signature to bytes once
	sigBytes := []byte(signature)

	// Calculate how many leading zero bits we need
	zeroBits := difficulty * 4 // Each hex digit = 4 bits
	zeroBytes := zeroBits / 8
	remainingBits := zeroBits % 8

	// Pre-allocate buffer with enough space
	buf := make([]byte, len(sigBytes), len(sigBytes)+20)
	copy(buf, sigBytes)

	nonce := uint64(0)

	// Keep track of where signature ends
	sigLen := len(sigBytes)

	// Single-threaded tight loop - maximum performance
	for {
		// Build data: signature + nonce (optimized - reuse buffer)
		buf = buf[:sigLen]
		buf = strconv.AppendUint(buf, nonce, 10)

		// Calculate hash
		hash := sha256.Sum256(buf)

		// Fast check: compare bytes directly instead of hex string
		isValid := true

		// Check full zero bytes
		for k := 0; k < zeroBytes; k++ {
			if hash[k] != 0 {
				isValid = false
				break
			}
		}

		// Check remaining bits if needed
		if isValid && remainingBits > 0 {
			mask := byte(0xFF << (8 - remainingBits))
			if (hash[zeroBytes] & mask) != 0 {
				isValid = false
			}
		}

		if isValid {
			duration := time.Since(startTime)
			log.Printf("PoW solved: nonce=%d, duration=%v", nonce, duration)
			return strconv.FormatUint(nonce, 10), duration
		}

		nonce++
	}
}

// getChallenge gets the PoW challenge
func (c *SearchClient) getChallenge() (*Challenge, error) {
	url := fmt.Sprintf("%s/auth/challenge?publicKey=%s", c.apiBase, c.GetPublicKeyHex())
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var challengeResp ChallengeResponse
	if err := json.Unmarshal(body, &challengeResp); err != nil {
		return nil, err
	}

	if !challengeResp.Success {
		return nil, fmt.Errorf("failed to get challenge: %s", challengeResp.Error)
	}

	return &challengeResp.Data, nil
}

// getChallengeSubmit gets the PoW challenge for data submission
func (c *SearchClient) getChallengeSubmit() (*Challenge, error) {
	url := fmt.Sprintf("%s/auth/challenge-submit?publicKey=%s", c.apiBase, c.GetPublicKeyHex())
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var challengeResp ChallengeResponse
	if err := json.Unmarshal(body, &challengeResp); err != nil {
		return nil, err
	}

	if !challengeResp.Success {
		return nil, fmt.Errorf("failed to get submit challenge: %s", challengeResp.Error)
	}

	return &challengeResp.Data, nil
}

// verify submits PoW solutions for verification
func (c *SearchClient) verify(solutions []Solution) (*VerifyResponse, error) {
	url := fmt.Sprintf("%s/auth/verify", c.apiBase)

	reqBody := VerifyRequest{
		PublicKey: c.GetPublicKeyHex(),
		Solutions: solutions,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	resp, err := c.httpClient.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var verifyResp VerifyResponse
	if err := json.Unmarshal(body, &verifyResp); err != nil {
		return nil, err
	}

	return &verifyResp, nil
}

// submitData submits user data (requires fresh PoW)
func (c *SearchClient) submitData(nknAddress, customId, nickname, phoneNumber string) (*SubmitResponse, error) {
	log.Printf("Starting user data submission...")

	// 1. Get submit challenge
	challenge, err := c.getChallengeSubmit()
	if err != nil {
		return nil, fmt.Errorf("failed to get submit challenge: %w", err)
	}

	// 2. Solve challenges
	solutions, err := c.solveChallenges(challenge)
	if err != nil {
		return nil, fmt.Errorf("failed to solve challenges: %w", err)
	}

	// 3. Prepare and submit data
	url := c.apiBase.JoinPath("data/submit")

	powSolution := PowSolution{
		PublicKey: c.GetPublicKeyHex(),
		Solutions: solutions,
	}

	reqBody := SubmitRequest{
		PublicKey:   c.GetPublicKeyHex(),
		PowSolution: powSolution,
		NknAddress:  nknAddress,
		CustomId:    customId,
		Nickname:    nickname,
		PhoneNumber: phoneNumber,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	log.Printf("Submitting user data to server...")
	resp, err := c.httpClient.Post(url.String(), "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Handle rate limit with detailed message
	if resp.StatusCode == 429 {
		log.Printf("⚠️  Rate limit exceeded. Server allows max 10 submits per minute.")
		log.Printf("Please wait a moment before retrying.")
		return nil, fmt.Errorf("rate limit exceeded (429): max 10 submits per minute. Please wait and retry")
	}

	var submitResp SubmitResponse
	if err := json.Unmarshal(body, &submitResp); err != nil {
		return nil, err
	}

	if submitResp.Success {
		log.Printf("✓ User data submitted successfully: %s", submitResp.Message)
	} else {
		log.Printf("✗ User data submission failed: %s", submitResp.Error)
	}

	return &submitResp, nil
}

// solveChallenges solves all challenges
func (c *SearchClient) solveChallenges(challenge *Challenge) ([]Solution, error) {
	solutions := make([]Solution, 0, len(challenge.Challenges))
	totalStart := time.Now()

	log.Printf("Starting to solve %d challenges with difficulty %d", len(challenge.Challenges), challenge.Difficulty)

	for i, ch := range challenge.Challenges {
		// Sign the challenge
		signature, err := c.sign(ch)
		if err != nil {
			return nil, fmt.Errorf("failed to sign challenge: %w", err)
		}

		// Calculate PoW
		log.Printf("Solving challenge %d/%d...", i+1, len(challenge.Challenges))
		nonce, duration := solvePoW(signature, challenge.Difficulty)
		log.Printf("Challenge %d/%d solved in %v (nonce: %s)", i+1, len(challenge.Challenges), duration, nonce)

		solutions = append(solutions, Solution{
			Challenge: ch,
			Signature: signature,
			Nonce:     nonce,
		})
	}

	totalDuration := time.Since(totalStart)
	log.Printf("All challenges solved! Total time: %v (avg: %v per challenge)",
		totalDuration, totalDuration/time.Duration(len(challenge.Challenges)))

	return solutions, nil
}
