"""
PaddleOCR FastAPI Server for Japanese/Chinese Text Recognition
"""
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from paddleocr import PaddleOCR
import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import io
import logging

# Configure logging - ensure logs are visible in console
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),  # Output to console
    ]
)
logger = logging.getLogger(__name__)

# Also use print for critical messages to ensure visibility
def log_and_print(message, level='info'):
    """Log and print message to ensure visibility"""
    if level == 'info':
        logger.info(message)
        print(f"[INFO] {message}")
    elif level == 'warning':
        logger.warning(message)
        print(f"[WARNING] {message}")
    elif level == 'error':
        logger.error(message)
        print(f"[ERROR] {message}")


def _preprocess_image(img):
    """
    Preprocess image to improve OCR accuracy:
    - Resize if too small
    - Enhance contrast and sharpness
    - Denoise
    - Apply CLAHE for better text visibility
    """
    try:
        # Convert BGR to RGB if needed
        if len(img.shape) == 3 and img.shape[2] == 3:
            # Check if it's BGR (OpenCV default)
            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        else:
            img_rgb = img
        
        # Convert to PIL for enhancement
        pil_img = Image.fromarray(img_rgb)
        
        # Don't resize - let PaddleOCR handle image size with its internal limits
        # Resizing can lose detail and reduce OCR accuracy
        width, height = pil_img.size
        min_size = 100  # Only resize if extremely small
        
        # Only resize if extremely small (less than 100px)
        if min(width, height) < min_size:
            scale = min_size / min(width, height)
            new_width = int(width * scale)
            new_height = int(height * scale)
            pil_img = pil_img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            logger.info(f"Resized very small image from {width}x{height} to {new_width}x{new_height}")
        else:
            logger.info(f"Keeping original image size {width}x{height} for maximum quality")
        
        # Minimal enhancement - avoid over-processing that can lose detail
        # Only enhance if image quality is poor
        # Skip enhancement for good quality images to preserve detail
        
        # Convert back to numpy array
        img_processed = np.array(pil_img)
        
        # Convert RGB back to BGR for OpenCV
        if len(img_processed.shape) == 3:
            img_processed = cv2.cvtColor(img_processed, cv2.COLOR_RGB2BGR)
        
        # Minimal processing - return image as-is to preserve maximum detail
        # Only apply light denoising if image has significant noise
        # For most manga images, original quality is best
        img_final = img_processed
        
        logger.info(f"Minimal preprocessing applied - preserving original image quality")
        
        logger.info(f"Image preprocessed: original {img.shape} -> final {img_final.shape}")
        return img_final
        
    except Exception as e:
        logger.warning(f"Error in image preprocessing: {e}, using original image")
        return img


app = FastAPI(title="PaddleOCR Server")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize PaddleOCR with Japanese support
# Models will be downloaded automatically on first run
logger.info("Initializing PaddleOCR...")
ocr = None
try:
    # Try to import paddle first to check if it's available
    try:
        import paddle
        logger.info(f"PaddlePaddle found: {paddle.__version__}")
    except ImportError:
        logger.warning("PaddlePaddle not found, but PaddleOCR 3.x may work with PaddleX")
        # PaddleOCR 3.x might work with PaddleX only
    
    ocr = PaddleOCR(
        use_textline_orientation=True,  # Enable angle classification for vertical text (replaces use_angle_cls)
        use_doc_orientation_classify=True,  # Enable document orientation classification
        use_doc_unwarping=False,  # Disable document unwarping for manga
        lang='japan',  # Japanese language model
        # Note: Detection parameters like text_det_limit_side_len are passed to predict() method
    )
    logger.info("PaddleOCR initialized successfully")
except ImportError as e:
    if "paddle" in str(e).lower():
        logger.error(f"PaddlePaddle is required but not installed: {e}")
        logger.error("Please install PaddlePaddle:")
        logger.error("  For Windows CPU: pip install paddlepaddle -i https://www.paddlepaddle.org.cn/packages/stable/cpu/")
        logger.error("  Note: PaddlePaddle may not support Python 3.14. Try Python 3.10-3.12")
    else:
        logger.error(f"Failed to import required module: {e}")
    ocr = None
except Exception as e:
    logger.error(f"Failed to initialize PaddleOCR: {e}")
    logger.error("Please check PaddleOCR installation and ensure models are downloaded")
    ocr = None


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "ocr_initialized": ocr is not None,
        "service": "PaddleOCR Server"
    }


@app.post("/ocr")
async def perform_ocr(file: UploadFile = File(...)):
    """
    Perform OCR on uploaded image file.
    
    Args:
        file: Image file (JPEG, PNG, etc.)
    
    Returns:
        JSON with recognized text and confidence score
    """
    if ocr is None:
        logger.error("OCR service not initialized - check server logs for initialization errors")
        raise HTTPException(
            status_code=503, 
            detail="OCR service not initialized. Please check server logs and ensure PaddleOCR models are downloaded."
        )
    
    try:
        # Read image file
        contents = await file.read()
        
        # Convert to numpy array
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image file")
        
        # Skip preprocessing to preserve maximum detail
        # Preprocessing can lose detail and reduce OCR accuracy
        # img = _preprocess_image(img)  # Disabled to preserve quality
        
        # Perform OCR
        log_and_print("=" * 60)
        log_and_print(f"Processing OCR (Japanese model) for image: {file.filename}")
        log_and_print(f"Image size: {img.shape}")
        log_and_print(f"No preprocessing - preserving original quality")
        # PaddleOCR 3.3.2: Use predict() instead of ocr() (ocr() is deprecated)
        # For vertical text, ensure proper orientation handling
        result = ocr.predict(
            img,
            use_textline_orientation=True,
            use_doc_orientation_classify=True,
            text_det_thresh=0.3,  # Lower threshold for better detection
            text_det_box_thresh=0.5,  # Lower box threshold
            text_rec_score_thresh=0.3,  # Very low recognition threshold to catch all text (was 0.5)
            text_det_limit_side_len=10000,  # Increase max side limit for large images (was 4000 default)
            text_det_limit_type='max',  # Use max side instead of min
            text_det_unclip_ratio=1.8,  # Increase unclip ratio for better text detection
        )
        
        # Debug: Log result type and structure
        log_and_print(f"OCR result type: {type(result)}")
        if result is not None:
            result_len = len(result) if isinstance(result, (list, tuple)) else 'N/A'
            log_and_print(f"OCR result length: {result_len}")
            if isinstance(result, list) and len(result) > 0:
                log_and_print(f"First item type: {type(result[0])}")
                first_keys = list(result[0].keys()) if isinstance(result[0], dict) else 'N/A'
                log_and_print(f"First item keys: {first_keys}")
                first_sample = str(result[0])[:500] if len(str(result[0])) > 500 else str(result[0])
                log_and_print(f"First item sample: {first_sample}")
        
        # Parse result - predict() returns different format than ocr()
        if result is None:
            logger.warning("OCR result is None")
            return {
                "text": "",
                "confidence": 0.0,
                "message": "No text detected - result is None"
            }
        
        if not isinstance(result, (list, tuple)) or len(result) == 0:
            logger.warning(f"OCR result is empty or invalid format: {type(result)}")
            return {
                "text": "",
                "confidence": 0.0,
                "message": f"No text detected - invalid result format: {type(result)}"
            }
        
        # Extract text from result
        # PaddleOCR 3.3.2 predict() returns: [{'rec_texts': [...], 'rec_scores': [...], ...}, ...]
        all_text = []
        all_confidences = []
        
        try:
            # New format: List of dicts with 'rec_texts' and 'rec_scores'
            if isinstance(result, list) and len(result) > 0:
                for page_result in result:
                    if isinstance(page_result, dict):
                        # Extract texts and scores
                        rec_texts = page_result.get('rec_texts', [])
                        rec_scores = page_result.get('rec_scores', [])
                        
                        log_and_print(f"Found {len(rec_texts)} text items, {len(rec_scores)} scores")
                        
                        # Log all detected texts for debugging
                        for i, text in enumerate(rec_texts):
                            score = rec_scores[i] if i < len(rec_scores) else 0.0
                            log_and_print(f"  Text[{i}]: '{text}' (confidence: {score:.3f})")
                        
                        # Match texts with scores - include ALL text, don't filter by confidence
                        for i, text in enumerate(rec_texts):
                            text_str = str(text).strip() if text else ""
                            # Include all non-empty text, regardless of confidence
                            if text_str:
                                all_text.append(text_str)
                                # Get corresponding score if available
                                if i < len(rec_scores):
                                    score = float(rec_scores[i])
                                    all_confidences.append(score)
                                else:
                                    all_confidences.append(0.5)  # Default confidence for missing scores
                        
                        # If no texts found, check for alternative keys
                        if not all_text:
                            # Try old format compatibility
                            if 'text' in page_result:
                                all_text.append(str(page_result['text']))
                                all_confidences.append(page_result.get('confidence', 0.9))
                    # Fallback: old format (nested lists)
                    elif isinstance(page_result, list):
                        logger.info("Parsing as old nested list format")
                        for line in page_result:
                            if line is None:
                                continue
                            if isinstance(line, list):
                                for word_info in line:
                                    if word_info is None:
                                        continue
                                    if isinstance(word_info, (list, tuple)) and len(word_info) >= 2:
                                        text_conf = word_info[1]
                                        if isinstance(text_conf, (list, tuple)) and len(text_conf) >= 2:
                                            text, confidence = text_conf[0], text_conf[1]
                                            if text and str(text).strip():
                                                all_text.append(str(text).strip())
                                                all_confidences.append(float(confidence))
        except Exception as e:
            logger.error(f"Error parsing OCR result: {e}", exc_info=True)
            logger.error(f"Result structure: {type(result)}, first item: {result[0] if result else 'None'}")
        
        # Combine all text - for Chinese/Japanese, join without spaces unless text naturally has spaces
        # Check if any text item contains spaces
        has_natural_spaces = any(" " in text for text in all_text) if all_text else False
        if has_natural_spaces:
            combined_text = " ".join(all_text) if all_text else ""
        else:
            # For Chinese/Japanese, join directly without spaces
            combined_text = "".join(all_text) if all_text else ""
        
        avg_confidence = sum(all_confidences) / len(all_confidences) if all_confidences else 0.0
        
        log_and_print(f"OCR completed: {len(all_text)} text blocks detected, combined length: {len(combined_text)}, text preview: {combined_text[:150] if combined_text else 'empty'}")
        
        if not all_text:
            logger.warning(f"No text extracted from result. Result structure: {type(result)}, length: {len(result) if isinstance(result, (list, tuple)) else 'N/A'}")
        
        return {
            "text": combined_text,
            "confidence": float(avg_confidence),
            "blocks": len(all_text)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"OCR error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"OCR processing failed: {str(e)}")


@app.post("/ocr-chinese")
async def perform_ocr_chinese(file: UploadFile = File(...)):
    """
    Perform OCR with Chinese language model.
    Useful for Traditional/Simplified Chinese text.
    """
    try:
        # Initialize Chinese OCR if not already done
        ocr_ch = PaddleOCR(
            use_textline_orientation=True,  # Enable angle classification for vertical text
            use_doc_orientation_classify=True,  # Enable document orientation classification
            use_doc_unwarping=False,  # Disable document unwarping for manga
            lang='ch',  # Chinese language model
            # Improved detection parameters for better accuracy
            text_det_thresh=0.3,  # Lower threshold for better detection
            text_det_box_thresh=0.5,  # Lower box threshold
            text_rec_score_thresh=0.3,  # Very low recognition threshold to catch all text (was 0.5) to catch more text
        )
        
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image file")
        
        # Skip preprocessing to preserve maximum detail for Chinese text
        # img = _preprocess_image(img)  # Disabled to preserve quality
        
        # PaddleOCR 3.3.2: Use predict() instead of ocr() (ocr() is deprecated)
        # For Chinese vertical text, use enhanced orientation detection
        log_and_print("=" * 60)
        log_and_print(f"Processing OCR (Chinese model) for image: {file.filename}")
        log_and_print(f"Image size: {img.shape}")
        log_and_print(f"No preprocessing - preserving original quality")
        result = ocr_ch.predict(
            img,
            use_textline_orientation=True,
            use_doc_orientation_classify=True,
            text_det_thresh=0.3,  # Lower threshold for better detection
            text_det_box_thresh=0.5,  # Lower box threshold
            text_rec_score_thresh=0.3,  # Very low recognition threshold to catch all text (was 0.5)
            text_det_limit_side_len=10000,  # Increase max side limit for large images (was 4000 default)
            text_det_limit_type='max',  # Use max side instead of min
            text_det_unclip_ratio=1.8,  # Increase unclip ratio for better text detection
        )
        
        # Debug: Log result type and structure
        log_and_print(f"Chinese OCR result type: {type(result)}")
        if result is not None:
            result_len = len(result) if isinstance(result, (list, tuple)) else 'N/A'
            log_and_print(f"Chinese OCR result length: {result_len}")
            if isinstance(result, list) and len(result) > 0:
                log_and_print(f"Chinese OCR first item type: {type(result[0])}")
                first_keys = list(result[0].keys()) if isinstance(result[0], dict) else 'N/A'
                log_and_print(f"Chinese OCR first item keys: {first_keys}")
                first_sample = str(result[0])[:500] if len(str(result[0])) > 500 else str(result[0])
                log_and_print(f"Chinese OCR first item sample: {first_sample}")
        
        # Parse result - same format handling as main OCR endpoint
        if result is None:
            logger.warning("Chinese OCR result is None")
            return {
                "text": "",
                "confidence": 0.0,
                "message": "No text detected - result is None"
            }
        
        if not isinstance(result, (list, tuple)) or len(result) == 0:
            logger.warning(f"Chinese OCR result is empty or invalid: {type(result)}")
            return {
                "text": "",
                "confidence": 0.0,
                "message": f"No text detected - invalid result format: {type(result)}"
            }
        
        all_text = []
        all_confidences = []
        text_with_positions = []  # Store text with position for sorting
        
        # Parse using same logic as main endpoint
        try:
            if isinstance(result, list) and len(result) > 0:
                for page_result in result:
                    if isinstance(page_result, dict):
                        rec_texts = page_result.get('rec_texts', [])
                        rec_scores = page_result.get('rec_scores', [])
                        rec_boxes = page_result.get('rec_boxes', [])  # Get detection boxes for sorting
                        
                        log_and_print(f"Chinese OCR: Found {len(rec_texts)} text items, {len(rec_scores)} scores, {len(rec_boxes)} boxes")
                        
                        # Log all detected texts for debugging
                        for i, text in enumerate(rec_texts):
                            score = rec_scores[i] if i < len(rec_scores) else 0.0
                            box_info = rec_boxes[i] if i < len(rec_boxes) else None
                            log_and_print(f"  Chinese Text[{i}]: '{text}' (confidence: {score:.3f}, box: {box_info})")
                        
                        if len(rec_texts) == 0:
                            log_and_print("Chinese OCR: No text items found in rec_texts!", 'warning')
                            result_keys = list(page_result.keys()) if isinstance(page_result, dict) else 'N/A'
                            log_and_print(f"Chinese OCR: Result keys: {result_keys}", 'warning')
                        
                        # Include ALL text with position info for sorting
                        for i, text in enumerate(rec_texts):
                            text_str = str(text).strip() if text else ""
                            if text_str:
                                # Get box position for sorting (top Y coordinate)
                                box = rec_boxes[i] if i < len(rec_boxes) else None
                                y_pos = 0
                                if box is not None:
                                    # Box format: [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                                    if isinstance(box, (list, tuple)) and len(box) > 0:
                                        if isinstance(box[0], (list, tuple)) and len(box[0]) > 1:
                                            y_pos = float(box[0][1])  # Top Y coordinate
                                
                                text_with_positions.append({
                                    'text': text_str,
                                    'y_pos': y_pos,
                                    'index': i,
                                    'score': float(rec_scores[i]) if i < len(rec_scores) else 0.5
                                })
                        
                        # Sort by Y position (top to bottom) to maintain reading order
                        text_with_positions.sort(key=lambda x: x['y_pos'])
                        
                        # Extract sorted text and scores
                        for item in text_with_positions:
                            all_text.append(item['text'])
                            all_confidences.append(item['score'])
                    elif isinstance(page_result, list):
                        # Old format fallback
                        for line in page_result:
                            if line is None or not isinstance(line, list):
                                continue
                            for word_info in line:
                                if word_info is None or not isinstance(word_info, (list, tuple)) or len(word_info) < 2:
                                    continue
                                text_conf = word_info[1]
                                if isinstance(text_conf, (list, tuple)) and len(text_conf) >= 2:
                                    text, confidence = text_conf[0], text_conf[1]
                                    if text and str(text).strip():
                                        all_text.append(str(text).strip())
                                        all_confidences.append(float(confidence))
        except Exception as e:
            logger.error(f"Error parsing Chinese OCR result: {e}", exc_info=True)
        
        # Combine all text - for Chinese, join without spaces unless text naturally has spaces
        has_natural_spaces = any(" " in text for text in all_text) if all_text else False
        if has_natural_spaces:
            combined_text = " ".join(all_text) if all_text else ""
        else:
            # For Chinese, join directly without spaces
            combined_text = "".join(all_text) if all_text else ""
        
        avg_confidence = sum(all_confidences) / len(all_confidences) if all_confidences else 0.0
        
        log_and_print(f"Chinese OCR completed: {len(all_text)} text blocks detected, combined length: {len(combined_text)}, text preview: {combined_text[:150] if combined_text else 'empty'}")
        
        return {
            "text": combined_text,
            "confidence": float(avg_confidence),
            "blocks": len(all_text)
        }
        
    except Exception as e:
        logger.error(f"Chinese OCR error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"OCR processing failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")

