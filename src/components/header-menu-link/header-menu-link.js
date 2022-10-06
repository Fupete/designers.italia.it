import * as React from "react"
import Icon from "../icon/icon"

const HeaderMenuLink = ({
	isDropDown,
	idMegamenu,
	label,
	url
}) => {

	const styles = 'nav-link'
		+ `${isDropDown ? ' dropdown-toggle' : ''}`
	
	function icon(boolean){
		if (boolean) {
			return (
				<Icon icon="sprites.svg#it-expand" size="xs"/>
			)
		}
	}

	return (
		<a
			className={styles}
			href={url ? url : '#'}
			data-bs-toggle={isDropDown ? 'dropdown' : undefined}
			aria-expanded={isDropDown ? 'false' : undefined}
			id={idMegamenu}
			>
			<span>{label}</span>
			{icon(isDropDown)}
		</a>
	)
}
export default HeaderMenuLink